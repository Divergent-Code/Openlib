import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlib/services/annas_archieve.dart';
import 'package:openlib/services/goodreads.dart';
import 'package:openlib/services/open_library.dart';
import 'package:openlib/providers/search_providers.dart';

final getTrendingBooks = FutureProvider<List<TrendingBookData>>((ref) async {
  GoodReads goodReads = GoodReads();
  final penguinTrending = PenguinRandomHouse(); 
  final bookDigits = BookDigits();

  List<TrendingBookData> trendingBooks = await Future.wait<List<TrendingBookData>>([
    goodReads.trendingBooks(),
    penguinTrending.trendingBooks(),
    bookDigits.trendingBooks(),
  ]).then((List<List<TrendingBookData>> listOfData) =>
      listOfData.expand((element) => element).toList());

  if (trendingBooks.isEmpty) {
    throw Exception('Nothing Trending Today :(');
  }
  trendingBooks.shuffle();
  return trendingBooks;
});

final getSubCategoryTypeList = FutureProvider.family
    .autoDispose<List<CategoryBookData>, String>((ref, url) async {
  SubCategoriesTypeList subCategoriesTypeList = SubCategoriesTypeList();
  List<CategoryBookData> subCategories =
      await subCategoriesTypeList.categoriesBooks(url: url);
  List<CategoryBookData> uniqueArray = subCategories.toSet().toList();
  uniqueArray.shuffle();
  return uniqueArray;
});

final searchProvider = FutureProvider.family
    .autoDispose<List<BookData>, String>((ref, searchQuery) async {
  if (searchQuery.isEmpty) return [];

  final AnnasArchieve annasArchieve = AnnasArchieve();
  List<BookData> data = await annasArchieve.searchBooks(
      searchQuery: searchQuery,
      content: ref.watch(getTypeValue),
      sort: ref.watch(getSortValue),
      fileType: ref.watch(getFileTypeValue),
      enableFilters: ref.watch(enableFiltersState));
  return data;
});

final bookInfoProvider =
    FutureProvider.family<BookInfoData, String>((ref, url) async {
  final AnnasArchieve annasArchieve = AnnasArchieve();
  BookInfoData data = await annasArchieve.bookInfo(url: url);
  return data;
});
