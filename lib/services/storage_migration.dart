// Dart imports:
import 'dart:io';

// Project imports:
import 'package:openlib/services/download_engine_host.dart';

// ---------------------------------------------------------------------------
// Result of a storage migration attempt.
// ---------------------------------------------------------------------------

enum MigrationResult {
  success,
  canceled,
  copyFailed,
}

// ---------------------------------------------------------------------------
// Storage migration logic.
//
// Pauses active downloads, copies files asynchronously, verifies each copy,
// deletes the source, and rolls back on any failure.
// ---------------------------------------------------------------------------

class StorageMigration {
  /// Moves all book files (including `.partial` downloads) from [from] to [to].
  ///
  /// The [engine] is paused before moving and resumed afterwards.
  /// [onProgress] is called after each file with `(moved, total)`.
  static Future<MigrationResult> migrate({
    required String from,
    required String to,
    required DownloadEngineHost engine,
    void Function(int moved, int total)? onProgress,
  }) async {
    final sourceDir = Directory(from);
    if (!await sourceDir.exists()) {
      // Nothing to move — treat as success.
      return MigrationResult.success;
    }

    final destDir = Directory(to);
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    // Pause all active downloads so .partial files are not being written.
    engine.pauseAll();

    // Give the engine a moment to finish flushing partial files.
    await Future.delayed(const Duration(milliseconds: 500));

    final entities = sourceDir.listSync(recursive: false);
    final files = entities.whereType<File>().toList();
    final total = files.length;

    final List<File> copied = [];

    try {
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final fileName = file.path.split(Platform.pathSeparator).last;
        final destPath = '$to${Platform.pathSeparator}$fileName';

        // Copy asynchronously (non-blocking).
        await file.copy(destPath);

        // Verify the copy succeeded by comparing sizes.
        final destFile = File(destPath);
        final srcSize = await file.length();
        final dstSize = await destFile.length();
        if (srcSize != dstSize) {
          throw Exception('Size mismatch for $fileName');
        }

        copied.add(destFile);
        onProgress?.call(i + 1, total);
      }

      // All copies verified — safe to delete sources.
      for (final file in files) {
        await file.delete();
      }

      return MigrationResult.success;
    } catch (_) {
      // Roll back: delete anything we copied to the destination.
      for (final copiedFile in copied) {
        try {
          if (await copiedFile.exists()) {
            await copiedFile.delete();
          }
        } catch (_) {
          // Best-effort cleanup.
        }
      }
      return MigrationResult.copyFailed;
    } finally {
      // Always resume downloads so the queue doesn't stall.
      engine.resumeAll();
    }
  }
}
