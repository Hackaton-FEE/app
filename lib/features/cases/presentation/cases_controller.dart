import 'package:flutter/foundation.dart';

import '../domain/case_draft.dart';
import '../domain/case_repository.dart';

class CasesController extends ChangeNotifier {
  CasesController(this._repository);

  final CaseRepository _repository;

  List<CaseDraft> get drafts => _repository.drafts;

  void addDraft(Uri sourceUrl) {
    _repository.addDraft(sourceUrl);
    notifyListeners();
  }

  void removeDraft(String id) {
    _repository.removeDraft(id);
    notifyListeners();
  }
}
