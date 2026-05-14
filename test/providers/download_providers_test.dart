import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlib/providers/constants.dart';
import 'package:openlib/providers/download_providers.dart';

void main() {
  group('Download Providers Tests', () {
    test('bytesToFileSize formats byte counts correctly', () {
      expect(bytesToFileSize(0), '0b');
      expect(bytesToFileSize(500), '500.0b');
      expect(bytesToFileSize(1024), '1.0 Kb');
      expect(bytesToFileSize(1048576), '1.0Mb');
      expect(bytesToFileSize(1572864), '1.5Mb'); // 1.5 * 1024 * 1024
      expect(bytesToFileSize(1073741824), '1.0Gb');
    });

    test('computed file sizes evaluate properly based on state changes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify default state
      expect(container.read(totalFileSizeInBytes), 0);
      expect(container.read(getTotalFileSize), '0b');
      
      expect(container.read(downloadedFileSizeInBytes), 0);
      expect(container.read(getDownloadedFileSize), '0b');

      // Update state and verify computed file size strings
      container.read(totalFileSizeInBytes.notifier).state = 1048576; // 1 Mb
      expect(container.read(getTotalFileSize), '1.0Mb');

      container.read(downloadedFileSizeInBytes.notifier).state = 524288; // 500 Kb
      expect(container.read(getDownloadedFileSize), '512.0 Kb'); 
    });

    test('process states are initialized correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(downloadState), ProcessState.waiting);
      expect(container.read(checkSumState), CheckSumProcessState.waiting);
      
      container.read(downloadState.notifier).state = ProcessState.running;
      expect(container.read(downloadState), ProcessState.running);
      
      container.read(checkSumState.notifier).state = CheckSumProcessState.success;
      expect(container.read(checkSumState), CheckSumProcessState.success);
    });
  });
}
