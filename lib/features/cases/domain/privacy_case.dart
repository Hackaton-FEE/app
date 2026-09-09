enum CaseCategory { personalData, impersonation, intimateContent, other }

/// Local lifecycle only. Neither state implies that a report has been sent.
enum CaseStatus { draft, archived }

class PrivacyCase {
  const PrivacyCase({
    required this.id,
    required this.title,
    required this.sourceUrl,
    required this.category,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final Uri sourceUrl;
  final CaseCategory category;
  final String notes;
  final CaseStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}
