import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlib/services/annas_archive.dart';
import 'package:openlib/services/goodreads.dart';
import 'package:openlib/services/open_library.dart';
import 'package:openlib/providers/search_providers.dart'
    show searchFiltersProvider;

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

  final AnnasArchive annasArchive = AnnasArchive();
  final filters = ref.watch(searchFiltersProvider);
  List<BookData> data = await annasArchive.searchBooks(
      searchQuery: searchQuery,
      content: filters.typeValue,
      sort: filters.sortValue,
      fileType: filters.fileTypeValue,
      enableFilters: filters.filtersEnabled);
  return data;
});

final bookInfoProvider =
    FutureProvider.family<BookInfoData, String>((ref, url) async {
  final AnnasArchive annasArchive = AnnasArchive();
  BookInfoData data = await annasArchive.bookInfo(url: url);
  return data;
});
