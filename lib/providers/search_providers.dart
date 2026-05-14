import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlib/providers/constants.dart';

// ---------------------------------------------------------------------------
// Unified State Object
// ---------------------------------------------------------------------------

class SearchFiltersState {
  final String selectedType;
  final String selectedSort;
  final String selectedFileType;
  final String query;
  final bool filtersEnabled;

  const SearchFiltersState({
    this.selectedType = 'All',
    this.selectedSort = 'Most Relevant',
    this.selectedFileType = 'All',
    this.query = '',
    this.filtersEnabled = true,
  });

  SearchFiltersState copyWith({
    String? selectedType,
    String? selectedSort,
    String? selectedFileType,
    String? query,
    bool? filtersEnabled,
  }) {
    return SearchFiltersState(
      selectedType: selectedType ?? this.selectedType,
      selectedSort: selectedSort ?? this.selectedSort,
      selectedFileType: selectedFileType ?? this.selectedFileType,
      query: query ?? this.query,
      filtersEnabled: filtersEnabled ?? this.filtersEnabled,
    );
  }

  // Computed getters — replace the old derived StateProviders
  String get typeValue => typeValues[selectedType] ?? '';
  String get sortValue => sortValues[selectedSort] ?? '';
  String get fileTypeValue =>
      selectedFileType == 'All' ? '' : selectedFileType.toLowerCase();
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class SearchFiltersNotifier extends Notifier<SearchFiltersState> {
  @override
  SearchFiltersState build() => const SearchFiltersState();

  void setType(String type) =>
      state = state.copyWith(selectedType: type);

  void setSort(String sort) =>
      state = state.copyWith(selectedSort: sort);

  void setFileType(String fileType) =>
      state = state.copyWith(selectedFileType: fileType);

  void setQuery(String query) =>
      state = state.copyWith(query: query);

  void enableFilters() =>
      state = state.copyWith(filtersEnabled: true);

  void disableFilters() =>
      state = state.copyWith(filtersEnabled: false);

  void reset() => state = build();
}

// ---------------------------------------------------------------------------
// Provider registration
// ---------------------------------------------------------------------------

final searchFiltersProvider =
    NotifierProvider<SearchFiltersNotifier, SearchFiltersState>(
        SearchFiltersNotifier.new);
