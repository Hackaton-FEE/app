import 'case_draft.dart';

abstract interface class CaseRepository {
  List<CaseDraft> get drafts;
  CaseDraft addDraft(Uri sourceUrl);
  void removeDraft(String id);
}
