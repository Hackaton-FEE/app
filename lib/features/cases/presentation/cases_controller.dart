import 'package:flutter/foundation.dart';

import '../domain/case_input.dart';
import '../domain/case_repository.dart';
import '../domain/privacy_case.dart';
import 'cases_state.dart';

/// Coordinates one repository instance. Views never write to storage directly.
class CasesController extends ChangeNotifier {
  CasesController(this._repository);

  final CaseRepository _repository;
  CasesState _state = CasesState();
  CaseFilter _filter = CaseFilter.active;
  String _query = '';
  bool _loadInProgress = false;
  bool _disposed = false;

  CasesState get state => _state;
  CaseFilter get filter => _filter;
  String get query => _query;
  int get activeCount =>
      _state.cases.where((item) => item.status == CaseStatus.draft).length;
  int get archivedCount => _state.cases.length - activeCount;

  List<PrivacyCase> get visibleCases {
    final term = _query.trim().toLowerCase();
    final status = _filter == CaseFilter.active
        ? CaseStatus.draft
        : CaseStatus.archived;
    return List.unmodifiable(
      _state.cases.where((item) {
        return item.status == status &&
            (item.title.toLowerCase().contains(term) ||
                item.sourceUrl.host.toLowerCase().contains(term));
      }),
    );
  }

  PrivacyCase? findCase(String id) {
    for (final item in _state.cases) {
      if (item.id == id) return item;
    }
    return null;
  }

  void setFilter(CaseFilter value) {
    if (_filter == value || _disposed) return;
    _filter = value;
    notifyListeners();
  }

  void search(String value) {
    if (_query == value || _disposed) return;
    _query = value;
    notifyListeners();
  }

  Future<void> load() async {
    if (_loadInProgress || _state.isSaving || _disposed) return;
    _loadInProgress = true;
    _emit(CasesState(cases: _state.cases));
    try {
      final cases = await _repository.loadCases();
      _emit(CasesState(cases: cases, isLoading: false));
    } catch (error) {
      _emit(
        CasesState(
          cases: _state.cases,
          isLoading: false,
          loadError: _errorMessage(error),
        ),
      );
    } finally {
      _loadInProgress = false;
    }
  }

  Future<PrivacyCase?> saveCase(CaseInput input, {String? id}) {
    return _execute(
      () => id == null
          ? _repository.createCase(input)
          : _repository.updateCase(id, input),
      (saved) => [..._state.cases.where((item) => item.id != saved.id), saved],
    );
  }

  Future<bool> setArchived(String id, bool archived) async {
    final saved = await _execute(
      () => _repository.setArchived(id, archived),
      (saved) => [..._state.cases.where((item) => item.id != saved.id), saved],
    );
    return saved != null;
  }

  Future<bool> deleteCase(String id) async {
    final deleted = await _execute(() async {
      await _repository.deleteCase(id);
      return true;
    }, (_) => _state.cases.where((item) => item.id != id).toList());
    return deleted ?? false;
  }

  Future<T?> _execute<T>(
    Future<T> Function() operation,
    List<PrivacyCase> Function(T result) updateCases,
  ) async {
    if (_disposed ||
        _state.isLoading ||
        _state.isSaving ||
        _state.loadError != null) {
      return null;
    }
    _emit(CasesState(cases: _state.cases, isLoading: false, isSaving: true));
    try {
      final result = await operation();
      if (_disposed) return null;
      final cases = updateCases(result)
        ..sort((a, b) {
          final byDate = b.updatedAt.compareTo(a.updatedAt);
          return byDate == 0 ? a.id.compareTo(b.id) : byDate;
        });
      _emit(CasesState(cases: cases, isLoading: false));
      return result;
    } catch (error) {
      _emit(
        CasesState(
          cases: _state.cases,
          isLoading: false,
          actionError: _errorMessage(error),
        ),
      );
      return null;
    }
  }

  String _errorMessage(Object error) {
    if (error is CaseRepositoryException) {
      return switch (error.reason) {
        CaseRepositoryExceptionReason.invalidStoredData => 'No pudimos leer los casos guardados. Conservamos los datos sin modificarlos.',
        CaseRepositoryExceptionReason.notFound =>
          'Este caso ya no está disponible. Vuelve a cargar tus casos.',
        CaseRepositoryExceptionReason.storageUnavailable => 'No pudimos acceder al almacenamiento. Desbloquea el dispositivo e inténtalo de nuevo.',
      };
    }
    return 'No pudimos completar la operación. Inténtalo de nuevo.';
  }

  void _emit(CasesState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
