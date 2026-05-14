import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlib/providers/constants.dart';
import 'package:openlib/services/annas_archive.dart' show BookInfoData;
import 'package:openlib/services/database.dart';
import 'package:openlib/services/download_file.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum DownloadStatus { idle, running, complete, failed }

enum ChecksumStatus { idle, running, success, failed }

// ---------------------------------------------------------------------------
// Unified State Object
// ---------------------------------------------------------------------------

class DownloadState {
  final DownloadStatus status;
  final ChecksumStatus checksumStatus;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final bool isMirrorActive;
  final CancelToken? cancelToken;
  final String? errorMessage;

  const DownloadState({
    this.status = DownloadStatus.idle,
    this.checksumStatus = ChecksumStatus.idle,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.isMirrorActive = false,
    this.cancelToken,
    this.errorMessage,
  });

  DownloadState copyWith({
    DownloadStatus? status,
    ChecksumStatus? checksumStatus,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    bool? isMirrorActive,
    CancelToken? cancelToken,
    String? errorMessage,
  }) {
    return DownloadState(
      status: status ?? this.status,
      checksumStatus: checksumStatus ?? this.checksumStatus,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      isMirrorActive: isMirrorActive ?? this.isMirrorActive,
      cancelToken: cancelToken ?? this.cancelToken,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // Formatted helpers used by the UI
  String get formattedDownloadedBytes => bytesToFileSize(downloadedBytes);
  String get formattedTotalBytes => bytesToFileSize(totalBytes);
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class DownloadNotifier extends Notifier<DownloadState> {
  @override
  DownloadState build() => const DownloadState();

  /// Starts the download for [data] from the given [mirrors].
  Future<void> startDownload({
    required BookInfoData data,
    required List<String> mirrors,
  }) async {
    state = state.copyWith(
      status: DownloadStatus.running,
      progress: 0.0,
      downloadedBytes: 0,
      totalBytes: 0,
      checksumStatus: ChecksumStatus.idle,
      isMirrorActive: false,
      errorMessage: null,
    );

    downloadFile(
      mirrors: mirrors,
      md5: data.md5,
      format: data.format!,
      onStart: () {
        state = state.copyWith(status: DownloadStatus.running);
      },
      onProgress: (int rcv, int total) async {
        state = state.copyWith(
          downloadedBytes: rcv,
          totalBytes: total,
          progress: total > 0 ? rcv / total : 0.0,
        );

        if (rcv == total && total > 0) {
          await _onDownloadComplete(data);
        }
      },
      cancelDownlaod: (CancelToken token) {
        state = state.copyWith(cancelToken: token);
      },
      mirrorStatus: (bool active) {
        state = state.copyWith(isMirrorActive: active);
      },
      onDownlaodFailed: (dynamic msg) {
        state = state.copyWith(
          status: DownloadStatus.failed,
          errorMessage: msg.toString(),
        );
      },
    );
  }

  /// Cancels the active download and resets to idle.
  void cancelDownload() {
    state.cancelToken?.cancel();
    state = build();
  }

  /// Resets state back to idle. Call this from the UI after dismissing
  /// the success or failure dialog.
  void reset() => state = build();

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  Future<void> _onDownloadComplete(BookInfoData data) async {
    state = state.copyWith(
      status: DownloadStatus.complete,
      checksumStatus: ChecksumStatus.running,
    );

    await _saveToLibrary(data);

    // ignore: unused_result
    ref.refresh(checkIdExists(data.md5));
    // ignore: unused_result
    ref.refresh(myLibraryProvider);

    try {
      final checkSum =
          await verifyFileCheckSum(md5Hash: data.md5, format: data.format!);
      state = state.copyWith(
        checksumStatus:
            checkSum == true ? ChecksumStatus.success : ChecksumStatus.failed,
      );
    } catch (_) {
      state = state.copyWith(checksumStatus: ChecksumStatus.failed);
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
// Provider registration (non-auto-disposing so it survives navigation)
// ---------------------------------------------------------------------------

final downloadNotifierProvider =
    NotifierProvider<DownloadNotifier, DownloadState>(DownloadNotifier.new);

// ---------------------------------------------------------------------------
// Utility (pure function — no Riverpod dependency)
// ---------------------------------------------------------------------------

String bytesToFileSize(int bytes) {
  const int decimals = 1;
  const suffixes = ["b", " Kb", "Mb", "Gb", "Tb"];
  if (bytes == 0) return '0${suffixes[0]}';
  final i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)}${suffixes[i]}';
}

// ---------------------------------------------------------------------------
// Remaining independent providers (not part of download state)
// ---------------------------------------------------------------------------

final cookieProvider = StateProvider<String>((ref) => "");
final userAgentProvider = StateProvider<String>((ref) => "");
final webViewLoadingState = StateProvider.autoDispose<bool>((ref) => true);
