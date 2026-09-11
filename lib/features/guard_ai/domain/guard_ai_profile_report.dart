class GuardAiReportSection {
  const GuardAiReportSection(this.title, this.description);
  final String title;
  final String description;
}

/// Structured report supplied by a repository; it never generates findings.
class GuardAiProfileReport {
  GuardAiProfileReport({
    required this.identity,
    required this.high,
    required this.medium,
    required this.low,
    required this.summary,
    required this.recommendation,
    required this.sourceNote,
    required Iterable<GuardAiReportSection> sections,
    this.action,
  }) : sections = List.unmodifiable(sections);

  final String identity;
  final int high;
  final int medium;
  final int low;
  final String summary;
  final String recommendation;
  final String sourceNote;
  final String? action;
  final List<GuardAiReportSection> sections;
  int get total => high + medium + low;
  int get priorityCount => high + medium;
  String get text =>
      '$identity\n\n$summary\n\n'
      '${sections.map((section) => '${section.title}\n${section.description}').join('\n\n')}'
      '\n\n$recommendation\n\n$sourceNote';
}
