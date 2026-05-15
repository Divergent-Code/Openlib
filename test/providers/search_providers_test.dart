import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlib/providers/search_providers.dart';

void main() {
  group('Search Providers Tests', () {
    // -----------------------------------------------------------------------
    // Default state
    // -----------------------------------------------------------------------
    test('searchFiltersProvider initialises with correct default values', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(searchFiltersProvider);
      expect(state.selectedType, 'All');
      expect(state.selectedSort, 'Most Relevant');
      expect(state.selectedFileType, 'All');
      expect(state.query, '');
      expect(state.filtersEnabled, true);
    });

    // -----------------------------------------------------------------------
    // Computed getters on initial state
    // -----------------------------------------------------------------------
    test('computed values evaluate correctly on default state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(searchFiltersProvider);
      // 'All' should map to empty string for API calls
      expect(state.typeValue, '');
      expect(state.sortValue, '');
      expect(state.fileTypeValue, '');
    });

    // -----------------------------------------------------------------------
    // Mutations via notifier
    // -----------------------------------------------------------------------
    test('setType updates selectedType and typeValue', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(searchFiltersProvider.notifier).setType('Fiction Books');
      final state = container.read(searchFiltersProvider);

      expect(state.selectedType, 'Fiction Books');
      expect(state.typeValue, 'book_fiction');
    });

    test('setSort updates selectedSort and sortValue', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(searchFiltersProvider.notifier).setSort('Newest');
      final state = container.read(searchFiltersProvider);

      expect(state.selectedSort, 'Newest');
      expect(state.sortValue, 'newest');
    });

    test('setFileType updates selectedFileType and fileTypeValue', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(searchFiltersProvider.notifier).setFileType('Epub');
      expect(container.read(searchFiltersProvider).fileTypeValue, 'epub');

      container.read(searchFiltersProvider.notifier).setFileType('PDF');
      expect(container.read(searchFiltersProvider).fileTypeValue, 'pdf');

      // Back to 'All' → empty string
      container.read(searchFiltersProvider.notifier).setFileType('All');
      expect(container.read(searchFiltersProvider).fileTypeValue, '');
    });

    test('enableFilters / disableFilters toggle filtersEnabled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(searchFiltersProvider.notifier).disableFilters();
      expect(container.read(searchFiltersProvider).filtersEnabled, false);

      container.read(searchFiltersProvider.notifier).enableFilters();
      expect(container.read(searchFiltersProvider).filtersEnabled, true);
    });

    test('setQuery updates query field', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(searchFiltersProvider.notifier).setQuery('flutter book');
      expect(container.read(searchFiltersProvider).query, 'flutter book');
    });

    test('reset restores all fields to defaults', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(searchFiltersProvider.notifier);
      notifier.setType('Fiction Books');
      notifier.setSort('Newest');
      notifier.setFileType('Epub');
      notifier.setQuery('some query');
      notifier.disableFilters();

      notifier.reset();
      final state = container.read(searchFiltersProvider);

      expect(state.selectedType, 'All');
      expect(state.selectedSort, 'Most Relevant');
      expect(state.selectedFileType, 'All');
      expect(state.query, '');
      expect(state.filtersEnabled, true);
    });
  });
}
