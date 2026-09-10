import '../../../shared/domain/profile_date.dart';
import 'footprint_correlation.dart';
import 'osint_report.dart';

/// Also used by local history; malformed optional data is never silently lost.
OsintReport decodeOsintReport(Map<String, dynamic> json) {
  try {
    final summary = json['summary'] as Map<String, dynamic>;
    final scanId = json['scan_id'] as String;
    if (scanId.trim().isEmpty) throw const FormatException();
    final risk = json['risk_level'] as String;
    if (!{'LOW', 'MODERATE', 'ELEVATED', 'HIGH'}.contains(risk)) {
      throw const FormatException();
    }
    return OsintReport(
      scanId: scanId,
      exposureScore: _integer(json['exposure_score'], maximum: 100),
      riskLevel: risk,
      partial: json['partial'] as bool,
      platformsFound: _integer(summary['platforms_found']),
      highConfidence: _integer(summary['high_confidence']),
      potentialMatches: _integer(summary['potential_matches']),
      rateLimited: _integer(summary['rate_limited']),
      enginesRun: _strings(summary['engines_run']),
      correlation: json['correlation'] == null
          ? null
          : _decodeCorrelation(json['correlation'] as Map<String, dynamic>),
    );
  } catch (_) {
    throw const FormatException('Los datos del escaneo no son válidos.');
  }
}

FootprintCorrelation _decodeCorrelation(Map<String, dynamic> json) {
  final graph = json['identity_graph'] as Map<String, dynamic>;
  final timeline = json['timeline'] as Map<String, dynamic>;
  final nodes = _objects(graph['nodes'])
      .map(
        (n) => IdentityNode(
          id: n['id'] as String,
          platform: n['platform'] as String,
          username: n['username'] as String?,
          category: n['category'] as String,
        ),
      )
      .toList();
  final ids = nodes.map((n) => n.id).toSet();
  if (ids.length != nodes.length) throw const FormatException();
  final edges = _objects(graph['edges']).map((e) {
    final source = e['source'] as String;
    final target = e['target'] as String;
    if (!ids.contains(source) || !ids.contains(target)) {
      throw const FormatException();
    }
    return IdentityEdge(
      source: source,
      target: target,
      shared: _strings(e['shared']),
      weight: _integer(e['weight']),
    );
  }).toList();
  final clusters = (graph['clusters'] as List).map(_strings).toList();
  if (clusters.any((cluster) => cluster.any((id) => !ids.contains(id)))) {
    throw const FormatException();
  }
  return FootprintCorrelation(
    nodes: nodes,
    edges: edges,
    clusters: clusters,
    timeline: CorrelationTimeline(
      entries: _objects(timeline['entries']).map(
        (e) => CorrelationTimelineEntry(
          platform: e['platform'] as String,
          username: e['username'] as String?,
          createdAt: _date(e['created_at'])!,
          ageYears: _number(e['age_years']),
        ),
      ),
      oldestPlatform: timeline['oldest_platform'] as String?,
      oldestDate: _date(timeline['oldest_date']),
      newestPlatform: timeline['newest_platform'] as String?,
      newestDate: _date(timeline['newest_date']),
      spanYears: _number(timeline['span_years']),
      oldAccounts: _strings(timeline['dormant_old_accounts']),
    ),
    contacts: _objects(json['reconstructed_contacts']).map(
      (c) => ReconstructedContact(
        kind: c['kind'] as String,
        pattern: c['pattern'] as String,
        sources: _strings(c['sources']),
        count: _integer(c['count']),
        consistentWithProvided: c['consistent_with_provided'] as bool?,
      ),
    ),
  );
}

List<Map<String, dynamic>> _objects(dynamic value) =>
    (value as List).cast<Map<String, dynamic>>();
List<String> _strings(dynamic value) => (value as List).cast<String>();
int _integer(dynamic value, {int? maximum}) {
  if (value is! int || value < 0 || (maximum != null && value > maximum)) {
    throw const FormatException();
  }
  return value;
}

double _number(dynamic value) {
  final number = (value as num).toDouble();
  if (!number.isFinite || number < 0) throw const FormatException();
  return number;
}

String? _date(dynamic value) {
  if (value == null) return null;
  final text = value as String;
  parseProfileDate(
    RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ? '${text}T00:00:00Z' : text,
  );
  return text;
}

Map<String, dynamic> encodeOsintReport(OsintReport report) => {
  'scan_id': report.scanId,
  'exposure_score': report.exposureScore,
  'risk_level': report.riskLevel,
  'partial': report.partial,
  'summary': {
    'platforms_found': report.platformsFound,
    'high_confidence': report.highConfidence,
    'potential_matches': report.potentialMatches,
    'rate_limited': report.rateLimited,
    'engines_run': report.enginesRun,
  },
  'correlation': report.correlation == null
      ? null
      : _encodeCorrelation(report.correlation!),
};

Map<String, dynamic> _encodeCorrelation(FootprintCorrelation correlation) => {
  'identity_graph': {
    'nodes': correlation.nodes
        .map(
          (n) => {
            'id': n.id,
            'platform': n.platform,
            'username': n.username,
            'category': n.category,
          },
        )
        .toList(),
    'edges': correlation.edges
        .map(
          (e) => {
            'source': e.source,
            'target': e.target,
            'shared': e.shared,
            'weight': e.weight,
          },
        )
        .toList(),
    'clusters': correlation.clusters,
  },
  'timeline': {
    'entries': correlation.timeline.entries
        .map(
          (e) => {
            'platform': e.platform,
            'username': e.username,
            'created_at': e.createdAt,
            'age_years': e.ageYears,
          },
        )
        .toList(),
    'oldest_platform': correlation.timeline.oldestPlatform,
    'oldest_date': correlation.timeline.oldestDate,
    'newest_platform': correlation.timeline.newestPlatform,
    'newest_date': correlation.timeline.newestDate,
    'span_years': correlation.timeline.spanYears,
    'dormant_old_accounts': correlation.timeline.oldAccounts,
  },
  'reconstructed_contacts': correlation.contacts
      .map(
        (c) => {
          'kind': c.kind,
          'pattern': c.pattern,
          'sources': c.sources,
          'count': c.count,
          'consistent_with_provided': c.consistentWithProvided,
        },
      )
      .toList(),
};
