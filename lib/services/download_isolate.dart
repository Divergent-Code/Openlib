// Dart imports:
import 'dart:isolate';

// Package imports:
import 'package:dio/dio.dart';

// ---------------------------------------------------------------------------
// Message protocol between main isolate and download isolate
// ---------------------------------------------------------------------------

/// Commands sent FROM main isolate TO the download isolate.
sealed class IsolateCommand {}

class CancelCommand extends IsolateCommand {}

/// Messages sent FROM download isolate TO the main isolate.
sealed class IsolateMessage {
  final String md5;
  const IsolateMessage(this.md5);
}

class ProgressMessage extends IsolateMessage {
  final int received;
  final int total;
  const ProgressMessage(super.md5, this.received, this.total);
}

class MirrorActiveMessage extends IsolateMessage {
  const MirrorActiveMessage(super.md5);
}

class CompleteMessage extends IsolateMessage {
  const CompleteMessage(super.md5);
}

class FailedMessage extends IsolateMessage {
  final String error;
  const FailedMessage(super.md5, this.error);
}

class StartMessage extends IsolateMessage {
  const StartMessage(super.md5);
}

// ---------------------------------------------------------------------------
// Parameters passed to the isolate entry point
// ---------------------------------------------------------------------------

class DownloadParams {
  final String md5;
  final String format;
  final List<String> mirrors;
  final String directory;
  final SendPort replyPort;
  final ReceivePort cancelPort;

  const DownloadParams({
    required this.md5,
    required this.format,
    required this.mirrors,
    required this.directory,
    required this.replyPort,
    required this.cancelPort,
  });
}

// ---------------------------------------------------------------------------
// Isolate entry point (top-level function — required by Dart isolates)
// ---------------------------------------------------------------------------

/// Entry point for the download isolate.
///
/// Must be a top-level function so it can be spawned via [Isolate.spawn].
void downloadIsolateEntry(DownloadParams params) {
  final dio = Dio();

  // Listen for cancellation from the main isolate.
  params.cancelPort.listen((_) {
    dio.close(force: true);
    params.replyPort.send(FailedMessage(params.md5, 'canceled'));
    Isolate.exit();
  });

  _isolateDownload(dio, params);
}

Future<void> _isolateDownload(Dio dio, DownloadParams params) async {
  final orderedMirrors = _reorderMirrors(params.mirrors);
  final workingMirror = await _getAliveMirror(dio, orderedMirrors);

  if (workingMirror == null) {
    params.replyPort
        .send(FailedMessage(params.md5, 'No working mirrors available'));
    Isolate.exit();
    return;
  }

  params.replyPort.send(StartMessage(params.md5));

  final path = '${params.directory}/${params.md5}.${params.format}';

  try {
    final cancelToken = CancelToken();
    // Hook the cancel port into a separate listener so we can cancel mid-download
    params.cancelPort.listen((_) {
      cancelToken.cancel();
      dio.close(force: true);
    });

    await dio.download(
      workingMirror,
      path,
      options: Options(headers: {
        'Connection': 'Keep-Alive',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.100 Safari/537.36'
      }),
      onReceiveProgress: (rcv, total) {
        if (!rcv.isNaN &&
            !rcv.isInfinite &&
            !total.isNaN &&
            !total.isInfinite) {
          params.replyPort.send(ProgressMessage(params.md5, rcv, total));
        }
      },
      deleteOnError: true,
      cancelToken: cancelToken,
    );

    params.replyPort.send(MirrorActiveMessage(params.md5));
    params.replyPort.send(CompleteMessage(params.md5));
  } catch (e) {
    if (e is DioException && e.type == DioExceptionType.cancel) {
      params.replyPort.send(FailedMessage(params.md5, 'canceled'));
    } else {
      params.replyPort.send(FailedMessage(params.md5, 'Download failed'));
    }
  }

  Isolate.exit();
}

// ---------------------------------------------------------------------------
// Mirror helpers (copied from download_file.dart — no external deps allowed)
// ---------------------------------------------------------------------------

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
