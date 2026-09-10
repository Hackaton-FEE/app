import '../../cases/domain/privacy_case.dart';
import 'footprint_item.dart';
import 'footprint_profile.dart';
import 'osint_report.dart';
import 'osint_report_codec.dart';

class ScanHistoryEntry {
  ScanHistoryEntry({
    required this.id,
    required this.targetIdentity,
    required this.scannedAt,
    required this.exposureScore,
    required this.overallRisk,
    required this.highRiskCount,
    required this.mediumRiskCount,
    required this.lowRiskCount,
    required Iterable<FootprintItem> items,
    this.osintReport,
  }) : items = List.unmodifiable(items);

  factory ScanHistoryEntry.fromProfile({
    required String id,
    required FootprintProfile profile,
    DateTime? scannedAt,
  }) {
    return ScanHistoryEntry(
      id: id,
      targetIdentity: profile.targetIdentity,
      scannedAt: (scannedAt ?? profile.lastScannedAt).toUtc(),
      exposureScore: profile.exposureScore,
      overallRisk: profile.overallRisk,
      highRiskCount: profile.highRiskCount,
      mediumRiskCount: profile.mediumRiskCount,
      lowRiskCount: profile.lowRiskCount,
      items: profile.items,
      osintReport: profile.osintReport,
    );
  }

  final String id;
  final String targetIdentity;
  final DateTime scannedAt;
  final int exposureScore;
  final FootprintRisk overallRisk;
  final int highRiskCount;
  final int mediumRiskCount;
  final int lowRiskCount;
  final List<FootprintItem> items;
  final OsintReport? osintReport;

  int get findingsCount => items.length;

  // Los registros anteriores no distinguían resultados del backend y ejemplos.
  bool get hasBackendReport => osintReport?.scanId.trim().isNotEmpty ?? false;

  static const maxRetention = Duration(days: 3);

  bool isExpired([DateTime? now]) {
    final current = (now ?? DateTime.now()).toUtc();
    return current.difference(scannedAt) >= maxRetention;
  }

  Duration remainingTime([DateTime? now]) {
    final current = (now ?? DateTime.now()).toUtc();
    final elapsed = current.difference(scannedAt);
    final remaining = maxRetention - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  FootprintProfile toProfile() {
    if (!hasBackendReport) {
      throw const FormatException(
        'Este registro no tiene una referencia verificable del escaneo.',
      );
    }
    return FootprintProfile(
      targetIdentity: targetIdentity,
      items: items,
      lastScannedAt: scannedAt.toLocal(),
      osintReport: osintReport,
    );
  }

  static int compareByRecency(ScanHistoryEntry a, ScanHistoryEntry b) =>
      b.scannedAt.compareTo(a.scannedAt);

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    if (osintReport != null) 'osintReport': encodeOsintReport(osintReport!),
    'id': id,
    'targetIdentity': targetIdentity,
    'scannedAt': scannedAt.toIso8601String(),
    'exposureScore': exposureScore,
    'overallRisk': overallRisk.name,
    'highRiskCount': highRiskCount,
    'mediumRiskCount': mediumRiskCount,
    'lowRiskCount': lowRiskCount,
    'items': items
        .map(
          (item) => {
            'id': item.id,
            'platform': item.platform,
            'category': item.category.name,
            'riskLevel': item.riskLevel.name,
            'title': item.title,
            'description': item.description,
            'exposedData': item.exposedData,
            'sourceUrl': item.sourceUrl,
            'recommendedAction': item.recommendedAction,
            'suggestedCaseCategory': item.suggestedCaseCategory.name,
            'rawDetails': item.rawDetails,
            'confidence': item.confidence,
          },
        )
        .toList(),
  };

  factory ScanHistoryEntry.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] is! int || json['schemaVersion'] != 1) {
      throw const FormatException('Versión de esquema no soportada');
    }
    for (final field in [
      'exposureScore',
      'highRiskCount',
      'mediumRiskCount',
      'lowRiskCount',
    ]) {
      final value = json[field];
      if (value is! int ||
          value < 0 ||
          (field == 'exposureScore' && value > 100)) {
        throw const FormatException('Resumen de escaneo inválido');
      }
    }
    final rawItems = json['items'] as List<dynamic>;
    final items = rawItems.map((raw) {
      final map = raw as Map<String, dynamic>;
      return FootprintItem(
        id: map['id'] as String,
        platform: map['platform'] as String,
        category: FootprintCategory.values.byName(map['category'] as String),
        riskLevel: FootprintRisk.values.byName(map['riskLevel'] as String),
        title: map['title'] as String,
        description: map['description'] as String,
        exposedData: (map['exposedData'] as List<dynamic>).cast<String>(),
        sourceUrl: map['sourceUrl'] as String,
        recommendedAction: map['recommendedAction'] as String,
        suggestedCaseCategory: CaseCategory.values.byName(
          map['suggestedCaseCategory'] as String,
        ),
        rawDetails: (map['rawDetails'] as Map<String, dynamic>?) ?? const {},
        confidence: (map['confidence'] as num?)?.toInt() ?? 80,
      );
    }).toList();

    return ScanHistoryEntry(
      id: json['id'] as String,
      targetIdentity: json['targetIdentity'] as String,
      scannedAt: DateTime.parse(json['scannedAt'] as String).toUtc(),
      exposureScore: (json['exposureScore'] as num).toInt(),
      overallRisk: FootprintRisk.values.byName(json['overallRisk'] as String),
      highRiskCount: (json['highRiskCount'] as num).toInt(),
      mediumRiskCount: (json['mediumRiskCount'] as num).toInt(),
      lowRiskCount: (json['lowRiskCount'] as num).toInt(),
      items: items,
      osintReport: json['osintReport'] == null
          ? null
          : decodeOsintReport(json['osintReport'] as Map<String, dynamic>),
    );
  }
}
