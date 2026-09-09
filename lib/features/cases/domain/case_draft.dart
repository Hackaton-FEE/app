/// A local draft. It never implies that a platform has received a report.
class CaseDraft {
  const CaseDraft({
    required this.id,
    required this.sourceUrl,
    required this.createdAt,
  });

  final String id;
  final Uri sourceUrl;
  final DateTime createdAt;
}
