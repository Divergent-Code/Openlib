import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlib/models/book.dart';
import 'package:openlib/providers/constants.dart' show annasArchiveMirrors;
import 'package:openlib/services/annas_archive.dart';

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
    DioException? lastError;
    for (final mirror in annasArchiveMirrors) {
      try {
        return await AnnasArchive(baseUrl: mirror).searchBooks(
          searchQuery: searchQuery,
          content: content,
          sort: sort,
          fileType: fileType,
          enableFilters: enableFilters,
        );
      } on DioException catch (e) {
        lastError = e;
        continue;
      }
    }
    // All mirrors exhausted — surface as a distinct typed exception.
    throw const AllMirrorsFailedException();
  }

  @override
  Future<BookInfoData> bookInfo({required String url}) async {
    for (final mirror in annasArchiveMirrors) {
      try {
        // Swap the host portion of the URL so detail pages also use the mirror.
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
