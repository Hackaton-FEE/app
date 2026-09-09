import '../domain/case_draft.dart';
import '../domain/case_repository.dart';

/// Demo storage only: a new repository starts empty and makes no network calls.
class InMemoryCaseRepository implements CaseRepository {
  final List<CaseDraft> _drafts = [];
  int _nextId = 1;

  @override
  List<CaseDraft> get drafts => List.unmodifiable(_drafts.reversed);

  @override
  CaseDraft addDraft(Uri sourceUrl) {
    final draft = CaseDraft(
      id: 'draft-${_nextId++}',
      sourceUrl: sourceUrl,
      createdAt: DateTime.now().toUtc(),
    );
    _drafts.add(draft);
    return draft;
  }

  @override
  void removeDraft(String id) {
    _drafts.removeWhere((draft) => draft.id == id);
  }
}
