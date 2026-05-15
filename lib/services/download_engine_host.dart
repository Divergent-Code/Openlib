// Dart imports:
import 'dart:async';
import 'dart:isolate';

// Project imports:
import 'package:openlib/services/download_engine.dart';

// ---------------------------------------------------------------------------
// Host-side controller for the background download engine isolate.
// ---------------------------------------------------------------------------

class DownloadEngineHost {
  Isolate? _isolate;
  SendPort? _commandPort;
  final _eventController = StreamController<EngineEvent>.broadcast();

  Stream<EngineEvent> get events => _eventController.stream;

  /// Spawns the worker isolate and waits for the handshake SendPort.
  Future<void> spawn() async {
    if (_isolate != null) return;

    final receivePort = ReceivePort();

    _isolate = await Isolate.spawn(
      downloadEngineEntry,
      _EngineParams(eventPort: receivePort.sendPort),
    );

    // First message from the isolate is its command-port SendPort.
    await for (final message in receivePort) {
      if (message is SendPort) {
        _commandPort = message;
        break;
      }
    }

    // Forward all subsequent messages as EngineEvents.
    receivePort.listen((message) {
      if (message is EngineEvent) {
        _eventController.add(message);
      }
    });
  }

  void _send(EngineCommand cmd) {
    _commandPort?.send(cmd);
  }

  void enqueue({
    required String md5,
    required String format,
    required List<String> mirrors,
    required String directory,
  }) {
    _send(EnqueueCommand(
      md5: md5,
      format: format,
      mirrors: mirrors,
      directory: directory,
    ));
  }

  void cancel(String md5) => _send(CancelCommand(md5));
  void pause(String md5) => _send(PauseCommand(md5));
  void resume(String md5) => _send(ResumeCommand(md5));

  void setConcurrency(int concurrency) {
    _send(SetConcurrencyCommand(concurrency));
  }

  void pauseAll() => _send(PauseAllCommand());
  void resumeAll() => _send(ResumeAllCommand());

  /// Kills the isolate. Used mainly for testing or app shutdown.
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _commandPort = null;
    _eventController.close();
  }
}

// ---------------------------------------------------------------------------
// Internal parameter class passed to the isolate entry point.
// ---------------------------------------------------------------------------

class _EngineParams {
  final SendPort eventPort;
  const _EngineParams({required this.eventPort});
}
