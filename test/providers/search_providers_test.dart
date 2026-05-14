import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlib/providers/search_providers.dart';

void main() {
  group('Search Providers Tests', () {
    test('providers should initialize with correct default values', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedTypeState), "All");
      expect(container.read(selectedSortState), "Most Relevant");
      expect(container.read(selectedFileTypeState), "All");
      expect(container.read(searchQueryProvider), "");
      expect(container.read(enableFiltersState), true);
    });

    test('computed provider values evaluate correctly based on state changes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify initial computed values map correctly to empty strings
      expect(container.read(getTypeValue), '');
      expect(container.read(getSortValue), '');
      expect(container.read(getFileTypeValue), '');

      // Update state and verify computed values change dynamically
      container.read(selectedTypeState.notifier).state = 'Fiction Books';
      expect(container.read(getTypeValue), 'book_fiction');

      container.read(selectedSortState.notifier).state = 'Newest';
      expect(container.read(getSortValue), 'newest');

      container.read(selectedFileTypeState.notifier).state = 'Epub';
      expect(container.read(getFileTypeValue), 'epub');
      
      container.read(selectedFileTypeState.notifier).state = 'PDF';
      expect(container.read(getFileTypeValue), 'pdf');
    });
  });
}
