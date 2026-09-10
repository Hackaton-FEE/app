/// Signals shared by public findings; they do not verify account ownership.
class FootprintCorrelation {
  FootprintCorrelation({
    required Iterable<IdentityNode> nodes,
    required Iterable<IdentityEdge> edges,
    required Iterable<Iterable<String>> clusters,
    required this.timeline,
    required Iterable<ReconstructedContact> contacts,
  }) : nodes = List.unmodifiable(nodes),
       edges = List.unmodifiable(edges),
       clusters = List.unmodifiable(clusters.map(List<String>.unmodifiable)),
       contacts = List.unmodifiable(contacts);

  final List<IdentityNode> nodes;
  final List<IdentityEdge> edges;
  final List<List<String>> clusters;
  final CorrelationTimeline timeline;
  final List<ReconstructedContact> contacts;
}

class IdentityNode {
  const IdentityNode({
    required this.id,
    required this.platform,
    required this.username,
    required this.category,
  });
  final String id;
  final String platform;
  final String? username;
  final String category;
  String get label => username == null ? platform : '$platform · $username';
}

class IdentityEdge {
  IdentityEdge({
    required this.source,
    required this.target,
    required Iterable<String> shared,
    required this.weight,
  }) : shared = List.unmodifiable(shared);
  final String source;
  final String target;
  final List<String> shared;
  final int weight;
}

class CorrelationTimeline {
  CorrelationTimeline({
    required Iterable<CorrelationTimelineEntry> entries,
    required this.oldestPlatform,
    required this.oldestDate,
    required this.newestPlatform,
    required this.newestDate,
    required this.spanYears,
    required Iterable<String> oldAccounts,
  }) : entries = List.unmodifiable(entries),
       oldAccounts = List.unmodifiable(oldAccounts);
  final List<CorrelationTimelineEntry> entries;
  final String? oldestPlatform;
  final String? oldestDate;
  final String? newestPlatform;
  final String? newestDate;
  final double spanYears;
  // The server calls these dormant_old_accounts, but only knows their age.
  final List<String> oldAccounts;
}

class CorrelationTimelineEntry {
  const CorrelationTimelineEntry({
    required this.platform,
    required this.username,
    required this.createdAt,
    required this.ageYears,
  });
  final String platform;
  final String? username;
  final String createdAt;
  final double ageYears;
}

class ReconstructedContact {
  ReconstructedContact({
    required this.kind,
    required this.pattern,
    required Iterable<String> sources,
    required this.count,
    required this.consistentWithProvided,
  }) : sources = List.unmodifiable(sources);
  final String kind;
  final String pattern;
  final List<String> sources;
  final int count;
  final bool? consistentWithProvided;
}
