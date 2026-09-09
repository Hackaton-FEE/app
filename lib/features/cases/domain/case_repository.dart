import 'case_input.dart';
import 'privacy_case.dart';

enum CaseRepositoryExceptionReason {
  storageUnavailable,
  invalidStoredData,
  notFound,
}

/// Carries only a reason; storage messages and personal data never escape.
class CaseRepositoryException implements Exception {
  const CaseRepositoryException(this.reason);

  final CaseRepositoryExceptionReason reason;

  @override
  String toString() => 'CaseRepositoryException(${reason.name})';
}

abstract interface class CaseRepository {
  Future<List<PrivacyCase>> loadCases();
  Future<PrivacyCase> createCase(CaseInput input);
  Future<PrivacyCase> updateCase(String id, CaseInput input);
  Future<PrivacyCase> setArchived(String id, bool archived);
  Future<void> deleteCase(String id);
}
