// Dart imports:
import 'dart:io';
import 'dart:math';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import 'package:openlib/providers/constants.dart';
import 'package:openlib/services/annas_archive.dart' show BookInfoData;
import 'package:openlib/services/database.dart';
import 'package:openlib/services/download_engine_host.dart';
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
    this.errorMessage,
  });

  DownloadTask copyWith({
    DownloadStatus? status,
    ChecksumStatus? checksumStatus,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    bool? isMirrorActive,
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
// Engine host singleton provider
// ---------------------------------------------------------------------------

final _downloadEngineHostProvider = Provider<DownloadEngineHost>((ref) {
  final host = DownloadEngineHost();

  host.spawn().then((_) {
    host.setConcurrency(ref.read(downloadConcurrencyProvider));
  });

  ref.onDispose(() {
    host.dispose();
  });

  return host;
});

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class DownloadNotifier extends Notifier<DownloadState> {
  DownloadEngineHost? _host;

  @override
  DownloadState build() {
    _host = ref.watch(_downloadEngineHostProvider);

    // Listen to engine events and update state.
    _host!.events.listen(_onEngineEvent);

    // Keep concurrency in sync.
    ref.listen(downloadConcurrencyProvider, (prev, next) {
      if (prev != next) {
        _host?.setConcurrency(next);
      }
    });

    return const DownloadState();
  }

  /// Adds a book to the queue.
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

    _host?.enqueue(
      md5: data.md5,
      format: data.format!,
      mirrors: mirrors,
      directory: '', // resolved asynchronously below
    );

    // Resolve directory and re-send if needed.
    _resolveDirectoryAndEnqueue(data.md5, data.format!, mirrors);
  }

  Future<void> _resolveDirectoryAndEnqueue(
    String md5,
    String format,
    List<String> mirrors,
  ) async {
    final db = MyLibraryDb.instance;
    final directory = await db.getPreference('bookStorageDirectory') as String;
    _host?.enqueue(
      md5: md5,
      format: format,
      mirrors: mirrors,
      directory: directory,
    );
  }

  /// Pauses a running download.
  void pauseDownload(String md5) {
    final task = state.tasks[md5];
    if (task == null || task.status != DownloadStatus.running) return;

    _host?.pause(md5);
    _updateTask(
      md5,
      task.copyWith(status: DownloadStatus.paused),
    );
  }

  /// Resumes a paused download.
  void resumeDownload(String md5) {
    final task = state.tasks[md5];
    if (task == null || task.status != DownloadStatus.paused) return;

    _host?.resume(md5);
    _updateTask(
      md5,
      task.copyWith(status: DownloadStatus.pending),
    );
  }

  /// Cancels a specific download and removes it from the queue.
  void cancelDownload(String md5) {
    final task = state.tasks[md5];
    if (task != null) {
      _host?.cancel(md5);
      dismissTask(md5);
    }
  }

  /// Removes a completed/failed/canceled task from the map.
  void dismissTask(String md5) {
    final newTasks = Map<String, DownloadTask>.from(state.tasks)..remove(md5);
    state = state.copyWith(tasks: newTasks);
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  void _updateTask(String md5, DownloadTask task) {
    state = state.copyWith(tasks: {...state.tasks, md5: task});
  }

  void _onEngineEvent(dynamic event) {
    if (event is ProgressEvent) {
      final t = state.tasks[event.md5];
      if (t == null) return;
      _updateTask(
        event.md5,
        t.copyWith(
          status: DownloadStatus.running,
          downloadedBytes: event.received,
          totalBytes: event.total,
          progress: event.total > 0 ? event.received / event.total : 0.0,
        ),
      );
    } else if (event is MirrorActiveEvent) {
      final t = state.tasks[event.md5];
      if (t == null) return;
      _updateTask(event.md5, t.copyWith(isMirrorActive: true));
    } else if (event is CompleteEvent) {
      final t = state.tasks[event.md5];
      if (t == null) return;
      _updateTask(
        event.md5,
        t.copyWith(
          status: DownloadStatus.complete,
          progress: 1.0,
        ),
      );
      _saveToLibrary(t.book);
      ref.refresh(checkIdExists(event.md5));
      ref.refresh(myLibraryProvider);
    } else if (event is FailedEvent) {
      final t = state.tasks[event.md5];
      if (t == null) return;
      final isCanceled = event.error == 'canceled';
      _updateTask(
        event.md5,
        t.copyWith(
          status: isCanceled ? DownloadStatus.canceled : DownloadStatus.failed,
          errorMessage: event.error,
        ),
      );
    } else if (event is ChecksumRunningEvent) {
      final t = state.tasks[event.md5];
      if (t == null) return;
      _updateTask(
        event.md5,
        t.copyWith(checksumStatus: ChecksumStatus.running),
      );
    } else if (event is ChecksumDoneEvent) {
      final t = state.tasks[event.md5];
      if (t == null) return;
      _updateTask(
        event.md5,
        t.copyWith(
          checksumStatus:
              event.success ? ChecksumStatus.success : ChecksumStatus.failed,
        ),
      );
    }
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
