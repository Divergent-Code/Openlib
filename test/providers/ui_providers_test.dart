import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlib/providers/ui_providers.dart';

void main() {
  group('UI Providers Tests', () {
    test('providers should initialize with correct default values', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedIndexProvider), 0);
      expect(container.read(homePageSelectedIndexProvider), 0);
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('state can be updated and read correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedIndexProvider.notifier).state = 2;
      expect(container.read(selectedIndexProvider), 2);

      container.read(homePageSelectedIndexProvider.notifier).state = 1;
      expect(container.read(homePageSelectedIndexProvider), 1);

      container.read(themeModeProvider.notifier).state = ThemeMode.dark;
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });
  });
}
