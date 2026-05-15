// Dart imports:
import 'dart:io';
import 'dart:isolate';

// Package imports:
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

// ---------------------------------------------------------------------------
// Message protocol: Host → Engine
// ---------------------------------------------------------------------------

sealed class EngineCommand {}

class EnqueueCommand extends EngineCommand {
  final String md5;
  final String format;
  final List<String> mirrors;
  final String directory;

  EnqueueCommand({
    required this.md5,
    required this.format,
    required this.mirrors,
    required this.directory,
  });
}

class CancelCommand extends EngineCommand {
  final String md5;
  CancelCommand(this.md5);
}

class PauseCommand extends EngineCommand {
  final String md5;
  PauseCommand(this.md5);
}

class ResumeCommand extends EngineCommand {
  final String md5;
  ResumeCommand(this.md5);
}

class SetConcurrencyCommand extends EngineCommand {
  final int concurrency;
  SetConcurrencyCommand(this.concurrency);
}

class PauseAllCommand extends EngineCommand {}

class ResumeAllCommand extends EngineCommand {}

// ---------------------------------------------------------------------------
// Message protocol: Engine → Host
// ---------------------------------------------------------------------------

sealed class EngineEvent {
  final String md5;
  const EngineEvent(this.md5);
}

class TaskEnqueuedEvent extends EngineEvent {
  const TaskEnqueuedEvent(super.md5);
}

class ProgressEvent extends EngineEvent {
  final int received;
  final int total;
  const ProgressEvent(super.md5, this.received, this.total);
}

class MirrorActiveEvent extends EngineEvent {
  const MirrorActiveEvent(super.md5);
}

class CompleteEvent extends EngineEvent {
  const CompleteEvent(super.md5);
}

class FailedEvent extends EngineEvent {
  final String error;
  const FailedEvent(super.md5, this.error);
}

class ChecksumRunningEvent extends EngineEvent {
  const ChecksumRunningEvent(super.md5);
}

class ChecksumDoneEvent extends EngineEvent {
  final bool success;
  const ChecksumDoneEvent(super.md5, this.success);
}

// ---------------------------------------------------------------------------
// Internal job state
// ---------------------------------------------------------------------------

enum _JobStatus { pending, running, paused, complete, failed, canceled }

class _DownloadJob {
  final String md5;
  final String format;
  final List<String> mirrors;
  final String directory;

  _JobStatus status = _JobStatus.pending;
  int received = 0;
  int total = 0;
  bool mirrorActive = false;
  CancelToken? cancelToken;
  String? error;

  _DownloadJob({
    required this.md5,
    required this.format,
    required this.mirrors,
    required this.directory,
  });

  String get partialPath => '$directory/$md5.$format.partial';
  String get finalPath => '$directory/$md5.$format';
}

// ---------------------------------------------------------------------------
// Engine entry point
// ---------------------------------------------------------------------------

class EngineParams {
  final SendPort eventPort;
  const EngineParams({required this.eventPort});
}

/// Top-level entry point for the background download isolate.
void downloadEngineEntry(EngineParams params) {
  final engine = _DownloadEngine(params.eventPort);
  engine.run();
}

// ---------------------------------------------------------------------------
// Engine implementation
// ---------------------------------------------------------------------------

class _DownloadEngine {
  final SendPort _eventPort;
  final Map<String, _DownloadJob> _jobs = {};
  final List<String> _queue = []; // ordered list of md5s
  final Set<String> _running = {};
  int _concurrency = 3;

  _DownloadEngine(this._eventPort);

  void run() {
    final commandPort = ReceivePort();
    _eventPort.send(commandPort.sendPort);

    commandPort.listen((message) {
      if (message is EngineCommand) {
        _handleCommand(message);
      }
    });
  }

  void _handleCommand(EngineCommand cmd) {
    switch (cmd) {
      case EnqueueCommand(:final md5, :final format, :final mirrors, :final directory):
        if (_jobs.containsKey(md5)) return;
        final job = _DownloadJob(
          md5: md5,
          format: format,
          mirrors: mirrors,
          directory: directory,
        );
        _jobs[md5] = job;
        _queue.add(md5);
        _emit(TaskEnqueuedEvent(md5));
        _processQueue();

      case CancelCommand(:final md5):
        final job = _jobs[md5];
        if (job == null) return;
        job.cancelToken?.cancel();
        job.status = _JobStatus.canceled;
        _running.remove(md5);
        _queue.remove(md5);
        _emit(FailedEvent(md5, 'canceled'));
        _processQueue();

      case PauseCommand(:final md5):
        final job = _jobs[md5];
        if (job == null || job.status != _JobStatus.running) return;
        job.cancelToken?.cancel();
        job.status = _JobStatus.paused;
        _running.remove(md5);
        _emit(FailedEvent(md5, 'canceled'));
        _processQueue();

      case ResumeCommand(:final md5):
        final job = _jobs[md5];
        if (job == null || job.status != _JobStatus.paused) return;
        job.status = _JobStatus.pending;
        job.error = null;
        if (!_queue.contains(md5)) _queue.add(md5);
        _processQueue();

      case SetConcurrencyCommand(:final concurrency):
        _concurrency = concurrency;
        _processQueue();

      case PauseAllCommand():
        for (final md5 in List<String>.from(_running)) {
          final job = _jobs[md5];
          if (job != null && job.status == _JobStatus.running) {
            job.cancelToken?.cancel();
            job.status = _JobStatus.paused;
            _running.remove(md5);
            _emit(FailedEvent(md5, 'canceled'));
          }
        }

      case ResumeAllCommand():
        for (final entry in _jobs.entries) {
          final job = entry.value;
          if (job.status == _JobStatus.paused) {
            job.status = _JobStatus.pending;
            job.error = null;
            if (!_queue.contains(entry.key)) _queue.add(entry.key);
          }
        }
        _processQueue();
    }
  }

  void _emit(EngineEvent event) {
    _eventPort.send(event);
  }

  void _processQueue() {
    final available = _concurrency - _running.length;
    if (available <= 0) return;

    final candidates = _queue
        .where((md5) => _jobs[md5]?.status == _JobStatus.pending)
        .take(available)
        .toList();

    for (final md5 in candidates) {
      final job = _jobs[md5]!;
      job.status = _JobStatus.running;
      job.cancelToken = CancelToken();
      _running.add(md5);
      _runJob(job);
    }
  }

  Future<void> _runJob(_DownloadJob job) async {
    final dio = Dio();

    try {
      final orderedMirrors = _reorderMirrors(job.mirrors);
      final workingMirror = await _getAliveMirror(dio, orderedMirrors);

      if (workingMirror == null) {
        job.status = _JobStatus.failed;
        job.error = 'No working mirrors available';
        _running.remove(job.md5);
        _emit(FailedEvent(job.md5, job.error!));
        _processQueue();
        return;
      }

      job.mirrorActive = true;
      _emit(MirrorActiveEvent(job.md5));

      final partialFile = File(job.partialPath);
      int resumeOffset = 0;

      if (await partialFile.exists()) {
        resumeOffset = await partialFile.length();
      }

      final options = Options(
        headers: {
          'Connection': 'Keep-Alive',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.100 Safari/537.36',
          if (resumeOffset > 0) 'Range': 'bytes=$resumeOffset-',
        },
      );

      await dio.download(
        workingMirror,
        job.partialPath,
        options: options,
        cancelToken: job.cancelToken,
        deleteOnError: false,
        onReceiveProgress: (rcv, total) {
          if (!rcv.isNaN &&
              !rcv.isInfinite &&
              !total.isNaN &&
              !total.isInfinite) {
            job.received = resumeOffset + rcv.toInt();
            job.total = resumeOffset + total.toInt();
            _emit(ProgressEvent(job.md5, job.received, job.total));
          }
        },
      );

      // Move partial → final
      if (await partialFile.exists()) {
        await partialFile.rename(job.finalPath);
      }

      job.status = _JobStatus.complete;
      _running.remove(job.md5);
      _emit(CompleteEvent(job.md5));

      // Checksum inside isolate
      await _verifyChecksum(job);

      _processQueue();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // Pause or user cancel — keep partial file for resume
        if (job.status != _JobStatus.canceled) {
          job.status = _JobStatus.paused;
        }
      } else {
        job.status = _JobStatus.failed;
        job.error = 'Download failed';
        _emit(FailedEvent(job.md5, job.error!));
      }
      _running.remove(job.md5);
      _processQueue();
    } catch (e) {
      job.status = _JobStatus.failed;
      job.error = 'Download failed';
      _running.remove(job.md5);
      _emit(FailedEvent(job.md5, job.error!));
      _processQueue();
    } finally {
      dio.close();
    }
  }

  Future<void> _verifyChecksum(_DownloadJob job) async {
    _emit(ChecksumRunningEvent(job.md5));
    try {
      final file = File(job.finalPath);
      if (!await file.exists()) {
        _emit(ChecksumDoneEvent(job.md5, false));
        return;
      }
      final stream = file.openRead();
      final hash = await md5.bind(stream).first;
      final success = job.md5 == hash.toString();
      _emit(ChecksumDoneEvent(job.md5, success));
    } catch (_) {
      _emit(ChecksumDoneEvent(job.md5, false));
    }
  }

  // -------------------------------------------------------------------------
  // Mirror helpers
  // -------------------------------------------------------------------------

  List<String> _reorderMirrors(List<String> mirrors) {
    final ipfsMirrors = <String>[];
    final httpsMirrors = <String>[];

    for (final element in mirrors) {
      if (element.contains('ipfs')) {
        ipfsMirrors.add(element);
      } else if (!element.startsWith('https://annas-archive.se') &&
          !element.startsWith('https://1lib.sk')) {
        httpsMirrors.add(element);
      }
    }
    return [...ipfsMirrors, ...httpsMirrors];
  }

  Future<String?> _getAliveMirror(Dio dio, List<String> mirrors) async {
    const timeOut = 15;
    if (mirrors.length == 1) {
      await Future.delayed(const Duration(seconds: 2));
      return mirrors[0];
    }
    for (final url in mirrors) {
      try {
        final response = await dio.head(
          url,
          options: Options(receiveTimeout: const Duration(seconds: timeOut)),
        );
        if (response.statusCode == 200) {
          return url;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
