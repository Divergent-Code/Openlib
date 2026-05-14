import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlib/providers/constants.dart';

final selectedTypeState = StateProvider<String>((ref) => "All");
final selectedSortState = StateProvider<String>((ref) => "Most Relevant");
final selectedFileTypeState = StateProvider<String>((ref) => "All");
final searchQueryProvider = StateProvider<String>((ref) => "");
final enableFiltersState = StateProvider<bool>((ref) => true);

final getTypeValue = Provider.autoDispose<String>((ref) {
  return typeValues[ref.watch(selectedTypeState)] ?? '';
});

final getSortValue = Provider.autoDispose<String>((ref) {
  return sortValues[ref.watch(selectedSortState)] ?? '';
});

final getFileTypeValue = Provider.autoDispose<String>((ref) {
  final selectedFile = ref.watch(selectedFileTypeState);
  return selectedFile == "All" ? '' : selectedFile.toLowerCase();
});
