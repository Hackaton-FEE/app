import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../domain/footprint_profile.dart';
import '../domain/scan_history_entry.dart';
import '../domain/scan_history_repository.dart';

class ScanHistoryController extends ChangeNotifier {
  ScanHistoryController(this._repository, {String Function()? idFactory})
    : _idFactory = idFactory ?? const Uuid().v4;

  final ScanHistoryRepository _repository;
  final String Function() _idFactory;
  List<ScanHistoryEntry> _entries = const [];
  int _pendingCount = 0;
  Future<void>? _pending;
  bool _disposed = false;
  String? _error;
  Future<List<ScanHistoryEntry>> Function()? _failedOperation;

  List<ScanHistoryEntry> get entries => _entries;
  int get count => _entries.length;
  bool get isLoading => _pendingCount > 0;
  String? get error => _error;

  Future<void> _run(Future<List<ScanHistoryEntry>> Function() operation) {
    if (_disposed) return Future.value();
    _pendingCount++;
    notifyListeners();
    Future<void> execute() async {
      if (_disposed) return;
      _error = null;
      try {
        final entries = await operation();
        if (_disposed) return;
        _entries = List.unmodifiable(entries);
        _failedOperation = null;
      } catch (_) {
        if (_disposed) return;
        _failedOperation = operation;
        _error = 'No se pudo completar la operación del historial. Reintenta para continuar.';
      } finally {
        _pendingCount--;
        if (!_disposed) notifyListeners();
      }
    }

    final result = _pending == null
        ? execute()
        : _pending!.then((_) => execute());
    _pending = result;
    return result;
  }

  Future<void> load() => _run(_repository.loadHistory);
  Future<void> retry() => _run(_failedOperation ?? _repository.loadHistory);

  Future<void> recordScan(FootprintProfile profile) {
    final entry = ScanHistoryEntry.fromProfile(
      id: profile.osintReport?.scanId ?? _idFactory(),
      profile: profile,
    );
    return _run(() async {
      await _repository.saveScan(entry);
      return _repository.loadHistory();
    });
  }

  Future<void> deleteScan(String id) => _run(() async {
    await _repository.deleteScan(id);
    return _repository.loadHistory();
  });

  Future<void> clearAll() => _run(() async {
    await _repository.clearAll();
    return const [];
  });

  @override
  void dispose() {
    _disposed = true;
    _failedOperation = null;
    super.dispose();
  }
}
