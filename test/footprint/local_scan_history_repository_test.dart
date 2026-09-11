import 'dart:convert';

import 'package:fee_app/features/footprint/data/local_scan_history_repository.dart';
import 'package:fee_app/features/footprint/domain/footprint_item.dart';
import 'package:fee_app/features/footprint/domain/scan_history_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_scan_history_storage.dart';

void main() {
  group('LocalScanHistoryRepository', () {
    late FakeScanHistoryStorage storage;
    DateTime clock() => DateTime.utc(2026, 9, 10, 12, 0);

    setUp(() {
      storage = FakeScanHistoryStorage();
    });

    test(
      'large report survives storage and repository recreation intact',
      () async {
        final entry = _largeEntry(2 * 1024 * 1024, clock());
        final repo = LocalScanHistoryRepository(storage: storage, clock: clock);
        expect(
          utf8.encode(jsonEncode(entry.toJson())).length,
          greaterThan(1024 * 1024),
        );
        await repo.saveScan(entry);
        final reopened = LocalScanHistoryRepository(
          storage: storage,
          clock: clock,
        );
        expect((await reopened.loadHistory()).single.toJson(), entry.toJson());
      },
    );

    test(
      'oversized report is rejected without pruning or overwriting',
      () async {
        final expired = _largeEntry(
          10,
          clock().subtract(const Duration(days: 4)),
        );
        await storage.write(expired.id, jsonEncode(expired.toJson()));
        final before = await storage.readAll();
        final repo = LocalScanHistoryRepository(storage: storage, clock: clock);
        await expectLater(
          repo.saveScan(
            _largeEntry(LocalScanHistoryRepository.maxRecordBytes, clock()),
          ),
          throwsFormatException,
        );
        expect(await storage.readAll(), before);
      },
    );

    test('saves and loads scan history successfully', () async {
      final repo = LocalScanHistoryRepository(storage: storage, clock: clock);
      final entry = ScanHistoryEntry(
        id: 'scan-1',
        targetIdentity: 'test@example.com',
        scannedAt: DateTime.utc(2026, 9, 10, 10, 0),
        exposureScore: 30,
        overallRisk: FootprintRisk.low,
        highRiskCount: 0,
        mediumRiskCount: 0,
        lowRiskCount: 1,
        items: [],
      );

      await repo.saveScan(entry);
      final history = await repo.loadHistory();

      expect(history.length, 1);
      expect(history.first.id, 'scan-1');
      expect(history.first.targetIdentity, 'test@example.com');
    });

    test('automatically prunes scans older than 3 days when loading', () async {
      final repo = LocalScanHistoryRepository(storage: storage, clock: clock);

      // Fresh scan (1 day old)
      final validScan = ScanHistoryEntry(
        id: 'valid-1',
        targetIdentity: 'valid@example.com',
        scannedAt: DateTime.utc(2026, 9, 9, 12, 0), // 24 hours ago
        exposureScore: 20,
        overallRisk: FootprintRisk.low,
        highRiskCount: 0,
        mediumRiskCount: 0,
        lowRiskCount: 0,
        items: [],
      );

      // Expired scan (3 days and 2 hours old)
      final expiredScan = ScanHistoryEntry(
        id: 'expired-1',
        targetIdentity: 'expired@example.com',
        scannedAt: DateTime.utc(2026, 9, 7, 10, 0), // 74 hours ago
        exposureScore: 50,
        overallRisk: FootprintRisk.medium,
        highRiskCount: 0,
        mediumRiskCount: 1,
        lowRiskCount: 0,
        items: [],
      );

      // Store both in storage
      await storage.write('valid-1', jsonEncode(validScan.toJson()));
      await storage.write('expired-1', jsonEncode(expiredScan.toJson()));

      // Load through repo
      final history = await repo.loadHistory();

      // Only valid scan should be returned
      expect(history.length, 1);
      expect(history.first.id, 'valid-1');

      // Expired scan should have been deleted from storage
      final storedKeys = (await storage.readAll()).keys;
      expect(storedKeys, contains('valid-1'));
      expect(storedKeys, isNot(contains('expired-1')));
    });

    test('deletes individual scan and clears all', () async {
      final repo = LocalScanHistoryRepository(storage: storage, clock: clock);
      final scanA = ScanHistoryEntry(
        id: 'scan-a',
        targetIdentity: 'a@example.com',
        scannedAt: DateTime.utc(2026, 9, 10, 8, 0),
        exposureScore: 10,
        overallRisk: FootprintRisk.low,
        highRiskCount: 0,
        mediumRiskCount: 0,
        lowRiskCount: 0,
        items: [],
      );
      final scanB = ScanHistoryEntry(
        id: 'scan-b',
        targetIdentity: 'b@example.com',
        scannedAt: DateTime.utc(2026, 9, 10, 9, 0),
        exposureScore: 15,
        overallRisk: FootprintRisk.low,
        highRiskCount: 0,
        mediumRiskCount: 0,
        lowRiskCount: 0,
        items: [],
      );

      await repo.saveScan(scanA);
      await repo.saveScan(scanB);
      expect((await repo.loadHistory()).length, 2);

      await repo.deleteScan('scan-a');
      final afterDelete = await repo.loadHistory();
      expect(afterDelete.length, 1);
      expect(afterDelete.first.id, 'scan-b');

      await repo.clearAll();
      expect((await repo.loadHistory()).isEmpty, isTrue);
    });
    test(
      'corruption prevents pruning or writing and preserves every record',
      () async {
        final repo = LocalScanHistoryRepository(storage: storage, clock: clock);
        final expired = ScanHistoryEntry(
          id: 'expired',
          targetIdentity: 'test@example.invalid',
          scannedAt: clock().subtract(const Duration(days: 4)),
          exposureScore: 0,
          overallRisk: FootprintRisk.low,
          highRiskCount: 0,
          mediumRiskCount: 0,
          lowRiskCount: 0,
          items: [],
        );
        await storage.write(expired.id, jsonEncode(expired.toJson()));
        await storage.write('corrupt', '{broken');
        final before = await storage.readAll();
        await expectLater(repo.loadHistory(), throwsFormatException);
        await expectLater(repo.saveScan(expired), throwsFormatException);
        expect(await storage.readAll(), before);
      },
    );

    test('failed expiry deletion is reported and can be retried', () async {
      final repo = LocalScanHistoryRepository(storage: storage, clock: clock);
      final expired = ScanHistoryEntry(
        id: 'expired',
        targetIdentity: 'test@example.invalid',
        scannedAt: clock().subtract(const Duration(days: 4)),
        exposureScore: 0,
        overallRisk: FootprintRisk.low,
        highRiskCount: 0,
        mediumRiskCount: 0,
        lowRiskCount: 0,
        items: [],
      );
      await storage.write(expired.id, jsonEncode(expired.toJson()));
      storage.failDelete = true;
      await expectLater(repo.loadHistory(), throwsStateError);
      expect((await storage.readAll()).keys, contains('expired'));
      storage.failDelete = false;
      expect(await repo.loadHistory(), isEmpty);
    });

    test(
      'recreating repository preserves scans and rejects mismatched IDs',
      () async {
        final repo = LocalScanHistoryRepository(storage: storage, clock: clock);
        final entry = ScanHistoryEntry(
          id: 'scan',
          targetIdentity: 'test@example.invalid',
          scannedAt: clock(),
          exposureScore: 0,
          overallRisk: FootprintRisk.low,
          highRiskCount: 0,
          mediumRiskCount: 0,
          lowRiskCount: 0,
          items: [],
        );
        await repo.saveScan(entry);
        final reopened = LocalScanHistoryRepository(
          storage: storage,
          clock: clock,
        );
        expect((await reopened.loadHistory()).single.id, entry.id);
        await storage.write('wrong-key', jsonEncode(entry.toJson()));
        await expectLater(reopened.loadHistory(), throwsFormatException);
      },
    );
  });
}

ScanHistoryEntry _largeEntry(int bytes, DateTime date) => ScanHistoryEntry(
  id: 'large-report',
  targetIdentity: 'example.invalid',
  scannedAt: date,
  exposureScore: 10,
  overallRisk: FootprintRisk.low,
  highRiskCount: 0,
  mediumRiskCount: 0,
  lowRiskCount: 1,
  items: [
    FootprintItem(
      id: 'finding',
      platform: 'Example',
      category: FootprintCategory.socialProfile,
      riskLevel: FootprintRisk.low,
      title: 'Test finding',
      description: 'Test',
      exposedData: const [],
      sourceUrl: 'https://example.invalid',
      recommendedAction: 'Review',
      rawDetails: {'details': 'a' * bytes},
    ),
  ],
);
