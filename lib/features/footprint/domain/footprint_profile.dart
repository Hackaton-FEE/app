import 'footprint_item.dart';
import 'osint_report.dart';

class FootprintProfile {
  FootprintProfile({
    required this.targetIdentity,
    required Iterable<FootprintItem> items,
    required this.lastScannedAt,
    this.hasScanned = true,
    this.osintReport,
  }) : items = List.unmodifiable(items);

  factory FootprintProfile.initial({required String targetIdentity}) =>
      FootprintProfile(
        targetIdentity: targetIdentity,
        items: const [],
        lastScannedAt: DateTime.fromMillisecondsSinceEpoch(0),
        hasScanned: false,
      );

  final String targetIdentity;
  final List<FootprintItem> items;
  final DateTime lastScannedAt;
  final bool hasScanned;
  final OsintReport? osintReport;

  int get exposureScore {
    if (!hasScanned) return 0;
    if (osintReport != null) return osintReport!.exposureScore;
    if (items.isEmpty) return 10;
    int points = 0;
    for (final item in items) {
      switch (item.riskLevel) {
        case FootprintRisk.high:
          points += 28;
          break;
        case FootprintRisk.medium:
          points += 15;
          break;
        case FootprintRisk.low:
          points += 6;
          break;
      }
    }
    return points.clamp(5, 95);
  }

  int get highRiskCount =>
      items.where((it) => it.riskLevel == FootprintRisk.high).length;

  int get mediumRiskCount =>
      items.where((it) => it.riskLevel == FootprintRisk.medium).length;

  int get lowRiskCount =>
      items.where((it) => it.riskLevel == FootprintRisk.low).length;

  FootprintRisk get overallRisk {
    if (osintReport != null) {
      return switch (osintReport!.riskLevel) {
        'HIGH' || 'ELEVATED' => FootprintRisk.high,
        'MODERATE' => FootprintRisk.medium,
        _ => FootprintRisk.low,
      };
    }
    if (highRiskCount > 0 || exposureScore >= 70) return FootprintRisk.high;
    if (mediumRiskCount > 0 || exposureScore >= 40) return FootprintRisk.medium;
    return FootprintRisk.low;
  }
}
