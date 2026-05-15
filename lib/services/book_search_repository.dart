import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlib/models/book.dart';
import 'package:openlib/providers/constants.dart'
    show annasArchiveMirrors, bookDetailCacheTtl;
import 'package:openlib/services/annas_archive.dart';
import 'package:openlib/services/database.dart' show MyLibraryDb;

// ---------------------------------------------------------------------------
// Typed exception — thrown when every mirror has been tried and failed.
// UI pattern-matches on this type to show the "Service Unavailable" widget.
// ---------------------------------------------------------------------------

class AllMirrorsFailedException implements Exception {
  const AllMirrorsFailedException();

  @override
  String toString() =>
      'AllMirrorsFailedException: all known mirrors are unreachable.';
}

// ---------------------------------------------------------------------------
// Abstract contract
// ---------------------------------------------------------------------------

abstract class BookSearchRepository {
  Future<List<BookData>> searchBooks({
    required String searchQuery,
    String content,
    String sort,
    String fileType,
    bool enableFilters,
  });

  Future<BookInfoData> bookInfo({required String url});
}

// ---------------------------------------------------------------------------
// Concrete implementation with ordered mirror fallback
// ---------------------------------------------------------------------------

class AnnasArchiveRepository implements BookSearchRepository {
  @override
  Future<List<BookData>> searchBooks({
    required String searchQuery,
    String content = '',
    String sort = '',
    String fileType = '',
    bool enableFilters = true,
  }) async {
    for (final mirror in annasArchiveMirrors) {
      try {
        return await AnnasArchive(baseUrl: mirror).searchBooks(
          searchQuery: searchQuery,
          content: content,
          sort: sort,
          fileType: fileType,
          enableFilters: enableFilters,
        );
      } on DioException catch (_) {
        continue;
      }
    }
    // All mirrors exhausted — surface as a distinct typed exception.
    throw const AllMirrorsFailedException();
  }

  @override
  Future<BookInfoData> bookInfo({required String url}) async {
    final md5 = _extractMd5(url);
    final db = MyLibraryDb.instance;

    // --- Cache lookup ---
    final cached = await db.getCachedBookInfo(md5);
    if (cached != null) {
      final cachedAt =
          DateTime.fromMillisecondsSinceEpoch(cached['cachedAt'] as int);
      final isStale =
          DateTime.now().difference(cachedAt) > bookDetailCacheTtl;

      if (isStale) {
        // Stale-while-revalidate: return immediately, refresh in background.
        _refreshInBackground(url);
      }
      return BookInfoData.fromMap(cached);
    }

    // --- Cache miss: fetch, cache, return ---
    return _fetchAndCache(url);
  }

  /// Extracts the md5 hash from the tail of a book detail URL.
  String _extractMd5(String url) {
    final segments = Uri.parse(url).pathSegments;
    return segments.isNotEmpty ? segments.last : url;
  }

  /// Fire-and-forget background refresh. Failures are silently swallowed.
  void _refreshInBackground(String url) {
    _fetchAndCache(url).catchError((Object _) => throw _);
  }

  /// Fetches from mirrors, writes to cache, evicts stale entries, returns result.
  Future<BookInfoData> _fetchAndCache(String url) async {
    final book = await _fetchFromMirrors(url);
    final db = MyLibraryDb.instance;
    // Opportunistic eviction — keeps the table lean without a scheduler.
    final cutoff = DateTime.now()
        .subtract(bookDetailCacheTtl)
        .millisecondsSinceEpoch;
    await db.evictExpiredBookCache(cutoff);
    await db.cacheBookInfo(book.toMap());
    return book;
  }

  /// Iterates through mirrors in order; throws [AllMirrorsFailedException]
  /// if every mirror fails.
  Future<BookInfoData> _fetchFromMirrors(String url) async {
    for (final mirror in annasArchiveMirrors) {
      try {
        final mirrorUrl =
            url.replaceFirst(RegExp(r'https://[^/]+'), mirror);
        return await AnnasArchive(baseUrl: mirror).bookInfo(url: mirrorUrl);
      } on DioException catch (_) {
        continue;
      }
    }
    throw const AllMirrorsFailedException();
  }
}

// ---------------------------------------------------------------------------
// Riverpod registration
// ---------------------------------------------------------------------------

final bookSearchRepositoryProvider = Provider<BookSearchRepository>(
  (ref) => AnnasArchiveRepository(),
);
