import 'package:fee_app/features/cases/domain/privacy_case.dart';
import 'package:fee_app/features/footprint/domain/footprint_item.dart';
import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:fee_app/features/footprint/domain/scan_history_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScanHistoryEntry', () {
    final sampleItem = FootprintItem(
      id: 'item-1',
      platform: 'TestPlatform',
      category: FootprintCategory.dataBreach,
      riskLevel: FootprintRisk.high,
      title: 'Breach Title',
      description: 'Breach Description',
      exposedData: ['email', 'password'],
      sourceUrl: 'https://example.com',
      recommendedAction: 'Change password',
      suggestedCaseCategory: CaseCategory.personalData,
    );

    test('creates entry from FootprintProfile correctly', () {
      final now = DateTime.utc(2026, 9, 10, 12, 0);
      final profile = FootprintProfile(
        targetIdentity: 'user@example.com',
        items: [sampleItem],
        lastScannedAt: now,
      );

      final entry = ScanHistoryEntry.fromProfile(
        id: 'scan-1',
        profile: profile,
        scannedAt: now,
      );

      expect(entry.id, 'scan-1');
      expect(entry.targetIdentity, 'user@example.com');
      expect(entry.scannedAt, now);
      expect(entry.findingsCount, 1);
      expect(entry.overallRisk, FootprintRisk.high);
      expect(entry.highRiskCount, 1);
    });

    test('3-day retention expiration logic works strictly', () {
      final scanTime = DateTime.utc(2026, 9, 7, 12, 0);
      final entry = ScanHistoryEntry(
        id: 'scan-exp',
        targetIdentity: 'test@example.com',
        scannedAt: scanTime,
        exposureScore: 50,
        overallRisk: FootprintRisk.medium,
        highRiskCount: 0,
        mediumRiskCount: 1,
        lowRiskCount: 0,
        items: [],
      );

      // Exactly 71 hours later (under 3 days) -> not expired
      final underThreeDays = DateTime.utc(2026, 9, 10, 11, 0);
      expect(entry.isExpired(underThreeDays), isFalse);
      expect(entry.remainingTime(underThreeDays).inHours, 1);

      // Exactly 72 hours later -> expired
      final exactlyThreeDays = DateTime.utc(2026, 9, 10, 12, 0);
      expect(entry.isExpired(exactlyThreeDays), isTrue);
      expect(entry.remainingTime(exactlyThreeDays), Duration.zero);

      // 73 hours later (over 3 days) -> expired
      final overThreeDays = DateTime.utc(2026, 9, 10, 13, 0);
      expect(entry.isExpired(overThreeDays), isTrue);
      expect(entry.remainingTime(overThreeDays), Duration.zero);
    });

    test('serializes and deserializes JSON roundtrip', () {
      final time = DateTime.utc(2026, 9, 10, 10, 30);
      final original = ScanHistoryEntry(
        id: 'scan-json',
        targetIdentity: 'json@example.com',
        scannedAt: time,
        exposureScore: 45,
        overallRisk: FootprintRisk.medium,
        highRiskCount: 0,
        mediumRiskCount: 2,
        lowRiskCount: 1,
        items: [sampleItem],
      );

      final json = original.toJson();
      final decoded = ScanHistoryEntry.fromJson(json);

      expect(decoded.id, original.id);
      expect(decoded.targetIdentity, original.targetIdentity);
      expect(decoded.scannedAt, original.scannedAt);
      expect(decoded.exposureScore, original.exposureScore);
      expect(decoded.overallRisk, original.overallRisk);
      expect(decoded.findingsCount, 1);
      expect(decoded.items.first.title, 'Breach Title');
    });

    test('sorts by recency correctly', () {
      final older = ScanHistoryEntry(
        id: 'old',
        targetIdentity: 'old@example.com',
        scannedAt: DateTime.utc(2026, 9, 8),
        exposureScore: 10,
        overallRisk: FootprintRisk.low,
        highRiskCount: 0,
        mediumRiskCount: 0,
        lowRiskCount: 0,
        items: [],
      );
      final newer = ScanHistoryEntry(
        id: 'new',
        targetIdentity: 'new@example.com',
        scannedAt: DateTime.utc(2026, 9, 10),
        exposureScore: 10,
        overallRisk: FootprintRisk.low,
        highRiskCount: 0,
        mediumRiskCount: 0,
        lowRiskCount: 0,
        items: [],
      );

      final list = [older, newer]..sort(ScanHistoryEntry.compareByRecency);
      expect(list.first.id, 'new');
      expect(list.last.id, 'old');
    });
  });
}
