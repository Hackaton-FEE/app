import '../domain/privacy_case.dart';

enum CaseFilter { active, archived }

/// An immutable snapshot for the views; records are published after persistence.
class CasesState {
  CasesState({
    List<PrivacyCase> cases = const [],
    this.isLoading = true,
    this.isSaving = false,
    this.loadError,
    this.actionError,
  }) : cases = List.unmodifiable(cases);

  final List<PrivacyCase> cases;
  final bool isLoading;
  final bool isSaving;
  final String? loadError;
  final String? actionError;

  bool get canSave => !isLoading && !isSaving && loadError == null;
}
