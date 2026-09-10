import 'package:fee_app/features/footprint/data/local_scan_history_repository.dart';
import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:fee_app/features/footprint/presentation/scan_history_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_scan_history_storage.dart';

void main() {
  group('ScanHistoryController', () {
    late FakeScanHistoryStorage storage;
    late LocalScanHistoryRepository repository;
    DateTime clock() => DateTime.utc(2026, 9, 10, 12, 0);

    setUp(() {
      storage = FakeScanHistoryStorage();
      repository = LocalScanHistoryRepository(storage: storage, clock: clock);
    });

    test('starts with empty list and loads data', () async {
      final controller = ScanHistoryController(repository);
      expect(controller.entries, isEmpty);
      expect(controller.count, 0);

      await controller.load();
      expect(controller.entries, isEmpty);
      expect(controller.isLoading, isFalse);
    });

    test('records scan from FootprintProfile and notifies listeners', () async {
      final controller = ScanHistoryController(
        repository,
        idFactory: () => 'fixed-id',
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      final profile = FootprintProfile(
        targetIdentity: 'nuevo@ejemplo.com',
        items: [],
        lastScannedAt: clock(),
      );

      await controller.recordScan(profile);

      expect(controller.count, 1);
      expect(controller.entries.first.id, 'fixed-id');
      expect(controller.entries.first.targetIdentity, 'nuevo@ejemplo.com');
      expect(notifications, greaterThan(0));
    });

    test('deletes scan and notifies listeners', () async {
      final controller = ScanHistoryController(repository);
      final profile = FootprintProfile(
        targetIdentity: 'a@ejemplo.com',
        items: [],
        lastScannedAt: clock(),
      );

      await controller.recordScan(profile);
      expect(controller.count, 1);

      final id = controller.entries.first.id;
      await controller.deleteScan(id);
      expect(controller.count, 0);
    });

    test('handles storage error gracefully', () async {
      storage.shouldFail = true;
      final controller = ScanHistoryController(repository);

      await controller.load();
      expect(controller.error, isNotNull);
      expect(controller.isLoading, isFalse);
    });
    test('retry saves a failed scan once and clears the error', () async {
      final controller = ScanHistoryController(
        repository,
        idFactory: () => 'retry-scan',
      );
      addTearDown(controller.dispose);
      storage.shouldFail = true;
      await controller.recordScan(
        FootprintProfile(
          targetIdentity: 'test@example.invalid',
          items: [],
          lastScannedAt: clock(),
        ),
      );
      expect(controller.error, isNotNull);
      expect(controller.entries, isEmpty);
      storage.shouldFail = false;
      await controller.retry();
      expect(controller.error, isNull);
      expect(controller.entries.single.id, 'retry-scan');
    });

    test('a scan queued behind a load is not dropped', () async {
      final controller = ScanHistoryController(repository);
      addTearDown(controller.dispose);
      final loading = controller.load();
      final saving = controller.recordScan(
        FootprintProfile(
          targetIdentity: 'test@example.invalid',
          items: [],
          lastScannedAt: clock(),
        ),
      );
      await Future.wait([loading, saving]);
      expect(controller.count, 1);
      expect(controller.isLoading, isFalse);
    });
  });
}
