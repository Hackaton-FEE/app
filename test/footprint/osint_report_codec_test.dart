import 'dart:convert';

import 'package:fee_app/features/footprint/data/local_scan_history_repository.dart';
import 'package:fee_app/features/footprint/domain/osint_report_codec.dart';
import 'package:fee_app/features/footprint/domain/scan_history_entry.dart';
import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backend_footprint_repository_test.dart' show dashboardFixture;
import 'fake_scan_history_storage.dart';

void main() {
  test('correlation collections are deeply immutable and round-trip', () {
    final report = decodeOsintReport(dashboardFixture());
    final graph = report.correlation!;
    expect(() => graph.nodes.clear(), throwsUnsupportedError);
    expect(() => graph.clusters.single.add('invented'), throwsUnsupportedError);
    expect(() => graph.edges.single.shared.clear(), throwsUnsupportedError);
    expect(() => graph.contacts.single.sources.clear(), throwsUnsupportedError);
    expect(
      encodeOsintReport(decodeOsintReport(encodeOsintReport(report))),
      encodeOsintReport(report),
    );
  });

  test('invalid optional correlation blocks history writes without deleting records', () async {
    final now = DateTime.utc(2026, 9, 10, 13);
    final entry = ScanHistoryEntry.fromProfile(
      id: 'saved',
      profile: FootprintProfile(
        targetIdentity: 'persona_demo',
        items: [],
        lastScannedAt: now,
        osintReport: decodeOsintReport(dashboardFixture()),
      ),
    );
    final corrupt = entry.toJson();
    corrupt['osintReport']['correlation']['timeline']['entries'][0]['created_at'] =
        'bad-date';
    final storage = FakeScanHistoryStorage({'saved': jsonEncode(corrupt)});
    final repository = LocalScanHistoryRepository(
      storage: storage,
      clock: () => now,
    );
    final before = await storage.readAll();
    await expectLater(repository.loadHistory(), throwsFormatException);
    await expectLater(repository.saveScan(entry), throwsFormatException);
    expect(await storage.readAll(), before);
  });

  test('empty scan IDs are invalid both from API and saved reports', () {
    for (final id in ['', '  ']) {
      final json = dashboardFixture()..['scan_id'] = id;
      expect(() => decodeOsintReport(json), throwsFormatException);
    }
  });

  test(
    'timeline dates must exist in the calendar and are never normalized',
    () {
      final invalidDates = [
        '2026-02-30',
        '2026-13-01',
        '2026-02-30T12:00:00Z',
        '2026-09-10T24:00:00Z',
        '2026-09-10T12:00:00+02:99',
      ];
      for (final date in invalidDates) {
        for (final field in ['created_at', 'oldest_date', 'newest_date']) {
          final json = dashboardFixture();
          final timeline = json['correlation']['timeline'];
          if (field == 'created_at') {
            timeline['entries'][0][field] = date;
          } else {
            timeline[field] = date;
          }
          expect(
            () => decodeOsintReport(json),
            throwsFormatException,
            reason: '$field: $date',
          );
        }
      }
    },
  );

  test('date-only and timestamp timeline values remain exact', () {
    final json = dashboardFixture();
    json['correlation']['timeline']['entries'][0]['created_at'] =
        '2024-02-29T12:00:00+00:00';
    final report = decodeOsintReport(json);
    expect(
      report.correlation!.timeline.entries.single.createdAt,
      '2024-02-29T12:00:00+00:00',
    );
    expect(report.correlation!.timeline.oldestDate, '2020-01-01');
  });
}
