import '../../../shared/domain/profile_date.dart';
import '../domain/osint_report.dart';
import '../domain/osint_report_codec.dart';

/// Validates the wire contract before any finding becomes presentation data.
class OsintDashboardPayload {
  const OsintDashboardPayload._(this.report, this.generatedAt, this.categories);

  final OsintReport report;
  final DateTime generatedAt;
  final List<OsintCategoryPayload> categories;

  factory OsintDashboardPayload.fromJson(Map<String, dynamic> json) {
    try {
      final report = decodeOsintReport(json);
      final generatedAt = parseProfileDate(json['generated_at']);
      final categories = (json['categories'] as List)
          .map((value) {
            final category = value as Map<String, dynamic>;
            final name = _text(category['name']);
            final color = category['color_hex'] as String;
            if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)) {
              throw const FormatException();
            }
            final items = (category['items'] as List)
                .map(
                  (value) => OsintFindingPayload._fromJson(
                    value as Map<String, dynamic>,
                  ),
                )
                .toList(growable: false);
            final count = category['items_count'] as int;
            if (count < 0 || count != items.length) {
              throw const FormatException();
            }
            return OsintCategoryPayload._(name, List.unmodifiable(items));
          })
          .toList(growable: false);
      return OsintDashboardPayload._(
        report,
        generatedAt,
        List.unmodifiable(categories),
      );
    } catch (_) {
      throw const FormatException('Los datos del escaneo no son válidos.');
    }
  }
}

class OsintCategoryPayload {
  const OsintCategoryPayload._(this.name, this.items);
  final String name;
  final List<OsintFindingPayload> items;
}

class OsintFindingPayload {
  OsintFindingPayload._fromJson(Map<String, dynamic> json)
    : platform = _text(json['platform']),
      username = _nullableText(json, 'username'),
      url = _nullableText(json, 'url'),
      status = _status(json['status']),
      confidence = _confidence(json['confidence']),
      sources = List.unmodifiable((json['sources'] as List).map(_text)),
      details = Map.unmodifiable(json['details'] as Map<String, dynamic>);

  final String platform;
  final String? username;
  final String? url;
  final String status;
  final int confidence;
  final List<String> sources;
  final Map<String, dynamic> details;
}

String _text(dynamic value) {
  if (value is! String || value.trim().isEmpty) throw const FormatException();
  return value;
}

String? _nullableText(Map<String, dynamic> json, String key) {
  // Pydantic requires these keys; their values may explicitly be null.
  if (!json.containsKey(key)) throw const FormatException();
  return json[key] as String?;
}

String _status(dynamic value) {
  if (value is! String ||
      !{'CONFIRMED', 'POTENTIAL_MATCH', 'RATE_LIMITED'}.contains(value)) {
    throw const FormatException();
  }
  return value;
}

int _confidence(dynamic value) {
  if (value is! int || value < 0 || value > 100) throw const FormatException();
  return value;
}
