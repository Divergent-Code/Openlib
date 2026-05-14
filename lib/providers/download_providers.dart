import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlib/providers/constants.dart';
import 'package:openlib/services/annas_archive.dart' show BookInfoData;
import 'package:openlib/services/database.dart';
import 'package:openlib/services/download_file.dart' show verifyFileCheckSum;
import 'package:openlib/services/download_isolate.dart';
import 'package:openlib/providers/library_providers.dart'
    show myLibraryProvider, checkIdExists;

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum DownloadStatus { pending, running, paused, complete, failed, canceled }

enum ChecksumStatus { idle, running, success, failed }

// ---------------------------------------------------------------------------
// Unified State Object
// ---------------------------------------------------------------------------

class DownloadTask {
  final BookInfoData book;
  final List<String> mirrors;
  final DownloadStatus status;
  final ChecksumStatus checksumStatus;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final bool isMirrorActive;
  final ReceivePort? cancelPort;
  final String? errorMessage;

  const DownloadTask({
    required this.book,
    required this.mirrors,
    this.status = DownloadStatus.pending,
    this.checksumStatus = ChecksumStatus.idle,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.isMirrorActive = false,
    this.cancelPort,
    this.errorMessage,
  });

  DownloadTask copyWith({
    DownloadStatus? status,
    ChecksumStatus? checksumStatus,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    bool? isMirrorActive,
    ReceivePort? cancelPort,
    String? errorMessage,
  }) {
    return DownloadTask(
      book: book,
      mirrors: mirrors,
      status: status ?? this.status,
      checksumStatus: checksumStatus ?? this.checksumStatus,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      isMirrorActive: isMirrorActive ?? this.isMirrorActive,
      cancelPort: cancelPort ?? this.cancelPort,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  String get formattedDownloadedBytes => bytesToFileSize(downloadedBytes);
  String get formattedTotalBytes => bytesToFileSize(totalBytes);
}

class DownloadState {
  final Map<String, DownloadTask> tasks;

  const DownloadState({
    this.tasks = const {},
  });

  DownloadState copyWith({
    Map<String, DownloadTask>? tasks,
  }) {
    return DownloadState(
      tasks: tasks ?? this.tasks,
    );
  }
}

// ---------------------------------------------------------------------------
// Concurrent downloads config provider
// ---------------------------------------------------------------------------

final downloadConcurrencyProvider = StateProvider<int>((ref) => 3);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class DownloadNotifier extends Notifier<DownloadState> {
  @override
  DownloadState build() => const DownloadState();

  /// Adds a book to the queue. Starts immediately if slots are available.
  void enqueueDownload({
    required BookInfoData data,
    required List<String> mirrors,
  }) {
    if (state.tasks.containsKey(data.md5)) return;

    final task = DownloadTask(
      book: data,
      mirrors: mirrors,
      status: DownloadStatus.pending,
    );

    _updateTask(data.md5, task);
    _processQueue();
  }

  /// Pauses a running download (sends cancel to isolate).
  void pauseDownload(String md5) {
    final task = state.tasks[md5];
    if (task == null || task.status != DownloadStatus.running) return;

    task.cancelPort?.send(CancelCommand());
    _updateTask(
      md5,
      task.copyWith(
        status: DownloadStatus.paused,
        cancelPort: null,
      ),
    );
    _processQueue();
  }

  /// Resumes a paused download (re-enqueues as pending).
  void resumeDownload(String md5) {
    final task = state.tasks[md5];
    if (task == null || task.status != DownloadStatus.paused) return;

    _updateTask(
      md5,
      task.copyWith(status: DownloadStatus.pending),
    );
    _processQueue();
  }

  /// Cancels a specific download and removes it from the queue.
  void cancelDownload(String md5) {
    final task = state.tasks[md5];
    if (task != null) {
      task.cancelPort?.send(CancelCommand());
      dismissTask(md5);
      _processQueue();
    }
  }

  /// Removes a completed/failed/canceled task from the map.
  void dismissTask(String md5) {
    final newTasks = Map<String, DownloadTask>.from(state.tasks)..remove(md5);
    state = state.copyWith(tasks: newTasks);
  }

  // -------------------------------------------------------------------------
  // Private Queue Management — Concurrent
  // -------------------------------------------------------------------------

  void _updateTask(String md5, DownloadTask task) {
    state = state.copyWith(tasks: {...state.tasks, md5: task});
  }

  void _processQueue() {
    final concurrency = ref.read(downloadConcurrencyProvider);
    final runningCount =
        state.tasks.values.where((t) => t.status == DownloadStatus.running).length;
    final availableSlots = concurrency - runningCount;

    if (availableSlots <= 0) return;

    final pendingTasks = state.tasks.values
        .where((t) => t.status == DownloadStatus.pending)
        .take(availableSlots)
        .toList();

    for (final task in pendingTasks) {
      _startDownload(task);
    }
  }

  Future<void> _startDownload(DownloadTask task) async {
    final md5 = task.book.md5;

    _updateTask(
      md5,
      task.copyWith(
        status: DownloadStatus.running,
        progress: 0.0,
        downloadedBytes: 0,
        totalBytes: 0,
        checksumStatus: ChecksumStatus.idle,
        isMirrorActive: false,
        errorMessage: null,
      ),
    );

    // Get the storage directory
    final db = MyLibraryDb.instance;
    final directory = await db.getPreference('bookStorageDirectory') as String;

    // Set up communication channels
    final replyPort = ReceivePort();
    final cancelPort = ReceivePort();

    // Store the cancel port so pause/cancel can send to it
    _updateTask(
      md5,
      state.tasks[md5]!.copyWith(cancelPort: cancelPort),
    );

    // Spawn the download isolate
    try {
      await Isolate.spawn(
        downloadIsolateEntry,
        DownloadParams(
          md5: md5,
          format: task.book.format!,
          mirrors: task.mirrors,
          directory: directory,
          replyPort: replyPort.sendPort,
          cancelPort: cancelPort.sendPort,
        ),
      );
    } catch (e) {
      _updateTask(
        md5,
        state.tasks[md5]!.copyWith(
          status: DownloadStatus.failed,
          errorMessage: 'Failed to spawn isolate: $e',
        ),
      );
      replyPort.close();
      cancelPort.close();
      _processQueue();
      return;
    }

    // Listen for messages from the isolate
    await for (final message in replyPort) {
      if (message is StartMessage) {
        // Download started — already marked as running
      } else if (message is ProgressMessage) {
        final t = state.tasks[md5];
        if (t == null) break;

        _updateTask(
          md5,
          t.copyWith(
            downloadedBytes: message.received,
            totalBytes: message.total,
            progress: message.total > 0 ? message.received / message.total : 0.0,
          ),
        );
      } else if (message is MirrorActiveMessage) {
        final t = state.tasks[md5];
        if (t != null) {
          _updateTask(md5, t.copyWith(isMirrorActive: true));
        }
      } else if (message is CompleteMessage) {
        await _onDownloadComplete(task.book);
        break;
      } else if (message is FailedMessage) {
        final isCanceled = message.error == 'canceled';
        _updateTask(
          md5,
          state.tasks[md5]!.copyWith(
            status: isCanceled ? DownloadStatus.canceled : DownloadStatus.failed,
            errorMessage: message.error,
          ),
        );
        _processQueue();
        break;
      }
    }

    replyPort.close();
    cancelPort.close();
  }

  Future<void> _onDownloadComplete(BookInfoData data) async {
    final md5 = data.md5;
    final t = state.tasks[md5];
    if (t != null) {
      _updateTask(
        md5,
        t.copyWith(
          status: DownloadStatus.complete,
          checksumStatus: ChecksumStatus.running,
        ),
      );
    }

    await _saveToLibrary(data);

    ref.refresh(checkIdExists(data.md5));
    ref.refresh(myLibraryProvider);

    try {
      final checkSum =
          await verifyFileCheckSum(md5Hash: data.md5, format: data.format!);
      final t2 = state.tasks[md5];
      if (t2 != null) {
        _updateTask(
          md5,
          t2.copyWith(
            checksumStatus:
                checkSum == true ? ChecksumStatus.success : ChecksumStatus.failed,
          ),
        );
      }
    } catch (_) {
      final t2 = state.tasks[md5];
      if (t2 != null) {
        _updateTask(md5, t2.copyWith(checksumStatus: ChecksumStatus.failed));
      }
    }

    _processQueue();
  }

  Future<void> _saveToLibrary(BookInfoData data) async {
    final db = MyLibraryDb.instance;
    await db.insert(MyBook(
      id: data.md5,
      title: data.title,
      author: data.author,
      thumbnail: data.thumbnail,
      link: data.link,
      publisher: data.publisher,
      info: data.info,
      format: data.format,
      description: data.description,
    ));
  }
}

// ---------------------------------------------------------------------------
// Provider registration
// ---------------------------------------------------------------------------

final downloadNotifierProvider =
    NotifierProvider<DownloadNotifier, DownloadState>(DownloadNotifier.new);

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

String bytesToFileSize(int bytes) {
  const int decimals = 1;
  const suffixes = ["b", " Kb", "Mb", "Gb", "Tb"];
  if (bytes == 0) return '0${suffixes[0]}';
  final i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)}${suffixes[i]}';
}

// ---------------------------------------------------------------------------
// Other independent providers
// ---------------------------------------------------------------------------

final cookieProvider = StateProvider<String>((ref) => "");
final userAgentProvider = StateProvider<String>((ref) => "");
final webViewLoadingState = StateProvider.autoDispose<bool>((ref) => true);
