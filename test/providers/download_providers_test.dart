import 'package:flutter_test/flutter_test.dart';
import 'package:openlib/models/book.dart';
import 'package:openlib/providers/download_providers.dart';

void main() {
  group('Download Providers Tests', () {
    // -----------------------------------------------------------------------
    // bytesToFileSize
    // -----------------------------------------------------------------------
    test('bytesToFileSize formats byte counts correctly', () {
      expect(bytesToFileSize(0), '0b');
      expect(bytesToFileSize(500), '500.0b');
      expect(bytesToFileSize(1024), '1.0 Kb');
      expect(bytesToFileSize(1048576), '1.0Mb');
      expect(bytesToFileSize(1572864), '1.5Mb'); // 1.5 * 1024 * 1024
      expect(bytesToFileSize(1073741824), '1.0Gb');
    });

    // -----------------------------------------------------------------------
    // DownloadTask — default values
    // -----------------------------------------------------------------------
    test('DownloadTask initialises with correct defaults', () {
      final book = BookInfoData(
        title: 'Test Book',
        author: 'Author',
        thumbnail: null,
        publisher: 'Publisher',
        info: 'info',
        link: 'https://example.com',
        md5: 'abc123',
        format: 'epub',
        mirror: null,
        description: null,
      );

      final task = DownloadTask(book: book, mirrors: []);

      expect(task.status, DownloadStatus.pending);
      expect(task.checksumStatus, ChecksumStatus.idle);
      expect(task.progress, 0.0);
      expect(task.downloadedBytes, 0);
      expect(task.totalBytes, 0);
      expect(task.isMirrorActive, false);
      expect(task.errorMessage, null);
    });

    // -----------------------------------------------------------------------
    // DownloadTask.copyWith — state transitions
    // -----------------------------------------------------------------------
    test('DownloadTask.copyWith updates only specified fields', () {
      final book = BookInfoData(
        title: 'Test Book',
        author: 'Author',
        thumbnail: null,
        publisher: 'Publisher',
        info: 'info',
        link: 'https://example.com',
        md5: 'abc123',
        format: 'epub',
        mirror: null,
        description: null,
      );

      final task = DownloadTask(book: book, mirrors: []);

      final running = task.copyWith(
        status: DownloadStatus.running,
        downloadedBytes: 512 * 1024,
        totalBytes: 1024 * 1024,
        progress: 0.5,
      );

      expect(running.status, DownloadStatus.running);
      expect(running.downloadedBytes, 524288);
      expect(running.totalBytes, 1048576);
      expect(running.progress, 0.5);
      expect(running.book.md5, 'abc123'); // unchanged field preserved
    });

    // -----------------------------------------------------------------------
    // DownloadTask — formatted byte getters
    // -----------------------------------------------------------------------
    test('DownloadTask.formattedBytes returns human-readable strings', () {
      final book = BookInfoData(
        title: 'Test Book',
        author: 'Author',
        thumbnail: null,
        publisher: 'Publisher',
        info: 'info',
        link: 'https://example.com',
        md5: 'abc123',
        format: 'epub',
        mirror: null,
        description: null,
      );

      final task = DownloadTask(
        book: book,
        mirrors: [],
        downloadedBytes: 512 * 1024, // 512 Kb
        totalBytes: 1024 * 1024, // 1 Mb
      );

      expect(task.formattedDownloadedBytes, '512.0 Kb');
      expect(task.formattedTotalBytes, '1.0Mb');
    });

    // -----------------------------------------------------------------------
    // DownloadState
    // -----------------------------------------------------------------------
    test('DownloadState initialises with empty task map', () {
      const state = DownloadState();
      expect(state.tasks, isEmpty);
    });

    test('DownloadState.copyWith adds tasks correctly', () {
      final book = BookInfoData(
        title: 'Test Book',
        author: 'Author',
        thumbnail: null,
        publisher: 'Publisher',
        info: 'info',
        link: 'https://example.com',
        md5: 'abc123',
        format: 'epub',
        mirror: null,
        description: null,
      );

      const initial = DownloadState();
      final task = DownloadTask(book: book, mirrors: []);
      final updated = initial.copyWith(tasks: {'abc123': task});

      expect(updated.tasks.length, 1);
      expect(updated.tasks['abc123']?.book.title, 'Test Book');
    });
  });
}
