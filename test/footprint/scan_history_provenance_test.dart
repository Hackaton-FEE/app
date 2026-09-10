import 'dart:convert';

import 'package:fee_app/features/footprint/data/backend_footprint_repository.dart';
import 'package:fee_app/features/footprint/data/local_scan_history_repository.dart';
import 'package:fee_app/features/footprint/data/osint_client.dart';
import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:fee_app/features/footprint/domain/osint_report_codec.dart';
import 'package:fee_app/features/footprint/domain/scan_history_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import '../support/mock_footprint_repository.dart';
import 'backend_footprint_repository_test.dart' show dashboardFixture;
import 'fake_scan_history_storage.dart';

void main() {
  test(
    'legacy history remains stored without becoming the active profile',
    () async {
      final now = DateTime.now().toUtc();
      final profile = await MockFootprintRepository().getProfile();
      final legacy = ScanHistoryEntry.fromProfile(
        id: 'legacy',
        profile: profile,
      );
      final storage = FakeScanHistoryStorage({
        'legacy': jsonEncode(legacy.toJson()),
      });
      final before = await storage.readAll();
      final history = LocalScanHistoryRepository(
        storage: storage,
        clock: () => now,
      );
      final backend = BackendFootprintRepository(
        client: OsintClient(
          httpClient: MockClient((_) async => throw StateError('No network')),
        ),
        targetIdentity: profile.targetIdentity,
        historyRepository: history,
      );

      final loaded = await backend.getProfile();

      expect(loaded.hasScanned, isFalse);
      expect(loaded.items, isEmpty);
      expect(loaded.targetIdentity, profile.targetIdentity);
      expect((await history.loadHistory()).single.hasBackendReport, isFalse);
      expect(legacy.toProfile, throwsFormatException);
      expect(await storage.readAll(), before);
    },
  );

  test(
    'confirmed report is selected past a more recent legacy entry',
    () async {
      final now = DateTime.now().toUtc();
      final profile = await MockFootprintRepository().getProfile();
      final legacy = ScanHistoryEntry.fromProfile(
        id: 'legacy',
        profile: profile,
        scannedAt: now,
      );
      final confirmed = ScanHistoryEntry.fromProfile(
        id: 'confirmed',
        profile: FootprintProfile(
          targetIdentity: profile.targetIdentity,
          items: [],
          lastScannedAt: now.subtract(const Duration(hours: 1)),
          osintReport: decodeOsintReport(dashboardFixture()),
        ),
      );
      final storage = FakeScanHistoryStorage({
        legacy.id: jsonEncode(legacy.toJson()),
        confirmed.id: jsonEncode(confirmed.toJson()),
      });
      final before = await storage.readAll();
      final backend = BackendFootprintRepository(
        client: OsintClient(
          httpClient: MockClient((_) async => throw StateError('No network')),
        ),
        targetIdentity: profile.targetIdentity,
        historyRepository: LocalScanHistoryRepository(
          storage: storage,
          clock: () => now,
        ),
      );

      final loaded = await backend.getProfile();

      expect(loaded.hasScanned, isTrue);
      expect(loaded.osintReport!.scanId, confirmed.osintReport!.scanId);
      expect(loaded.exposureScore, confirmed.exposureScore);
      expect(await storage.readAll(), before);
    },
  );

  test('empty backend reference rejects history without deleting it', () async {
    final raw = dashboardFixture()..['scan_id'] = '   ';
    final entry = ScanHistoryEntry.fromProfile(
      id: 'empty-reference',
      profile: FootprintProfile(
        targetIdentity: 'test_alias',
        items: [],
        lastScannedAt: DateTime.now(),
      ),
    );

    final stored = entry.toJson()..['osintReport'] = raw;
    final storage = FakeScanHistoryStorage({entry.id: jsonEncode(stored)});
    final before = await storage.readAll();
    final history = LocalScanHistoryRepository(storage: storage);
    await expectLater(history.loadHistory(), throwsFormatException);
    expect(await storage.readAll(), before);
  });
}
