import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlib/services/database.dart';
import 'package:openlib/services/files.dart';
import 'package:openlib/providers/constants.dart';
import 'package:openlib/providers/reader_providers.dart';

MyLibraryDb dataBase = MyLibraryDb.instance;

final myLibraryProvider = FutureProvider((ref) async {
  return dataBase.getAll();
});

final checkIdExists =
    FutureProvider.family.autoDispose<bool, String>((ref, id) async {
  return await dataBase.checkIdExists(id);
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
  return await dataBase.getBookState(fileName);
});

Future<void> savePdfState(String fileName, WidgetRef ref) async {
  String position = ref.watch(pdfCurrentPage).toString();
  await dataBase.saveBookState(fileName, position);
}

Future<void> saveEpubState(
    String fileName, String? position, WidgetRef ref) async {
  String pos = position ?? '';
  await dataBase.saveBookState(fileName, pos);
}
