import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlib/services/database.dart';
import 'package:openlib/services/files.dart';
import 'package:openlib/providers/constants.dart';
import 'package:openlib/providers/reader_providers.dart';


final myLibraryProvider = FutureProvider((ref) async {
  return MyLibraryDb.instance.getAll();
});

final checkIdExists =
    FutureProvider.family.autoDispose<bool, String>((ref, id) async {
  return await MyLibraryDb.instance.checkIdExists(id);
});

final deleteFileFromMyLib =
    FutureProvider.family<void, FileName>((ref, fileName) async {
  return await deleteFileWithDbData(ref, fileName.md5, fileName.format);
});

final filePathProvider =
    FutureProvider.family<String, String>((ref, fileName) async {
  String path = await getFilePath(fileName);
  return path;
});

final getBookPosition =
    FutureProvider.family.autoDispose<String?, String>((ref, fileName) async {
  return await MyLibraryDb.instance.getBookState(fileName);
});

// ---------------------------------------------------------------------------
// Notifier — replaces savePdfState() and saveEpubState() free functions
// ---------------------------------------------------------------------------

class LibraryNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> savePdfPosition(String fileName) async {
    final page = ref.read(pdfCurrentPage);
    await MyLibraryDb.instance.saveBookState(fileName, page.toString());
  }

  Future<void> saveEpubPosition(String fileName, String? position) async {
    await MyLibraryDb.instance.saveBookState(fileName, position ?? '');
  }
}

final libraryNotifierProvider =
    NotifierProvider<LibraryNotifier, void>(LibraryNotifier.new);
