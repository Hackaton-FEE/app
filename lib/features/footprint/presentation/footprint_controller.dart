import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/footprint_item.dart';
import '../domain/footprint_profile.dart';
import '../domain/footprint_repository.dart';

class FootprintController extends ChangeNotifier {
  FootprintController(this._repository, {this.onScanCompleted});

  final Future<void> Function(FootprintProfile)? onScanCompleted;

  final FootprintRepository _repository;

  FootprintProfile? _profile;
  bool _isLoading = false;
  bool _disposed = false;
  String? _error;
  String? _failedScanIdentity;
  String? _scanningStage;
  FootprintCategory? _selectedCategory;

  FootprintProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get scanningStage => _scanningStage;
  FootprintCategory? get selectedCategory => _selectedCategory;

  List<FootprintItem> get visibleItems {
    if (_profile == null) return const [];
    if (_selectedCategory == null) return _profile!.items;
    return List.unmodifiable(
      _profile!.items.where((item) => item.category == _selectedCategory),
    );
  }

  void setCategoryFilter(FootprintCategory? category) {
    if (_disposed) return;
    if (_selectedCategory == category) {
      _selectedCategory = null;
    } else {
      _selectedCategory = category;
    }
    _notify();
  }

  void updateStage(String stage) {
    if (_disposed || !_isLoading) return;
    _scanningStage = stage;
    _notify();
  }

  void setProfile(FootprintProfile profile) {
    if (_disposed || _isLoading) return;
    _profile = profile;
    _error = null;
    _failedScanIdentity = null;
    _selectedCategory = null;
    _notify();
  }

  Future<void> retry() async {
    if (_disposed || _isLoading || _error == null) return;
    final identity = _failedScanIdentity;
    if (identity == null) {
      await loadProfile();
    } else {
      await scanIdentity(identity);
    }
  }

  Future<void> loadProfile() async {
    if (_disposed || _isLoading) return;
    _isLoading = true;
    _error = null;
    _failedScanIdentity = null;
    _notify();

    try {
      final profile = await _repository.getProfile();
      if (_disposed) return;
      _profile = profile;
    } catch (_) {
      if (!_disposed) {
        _error = 'No se pudo cargar la información de huella digital.';
      }
    } finally {
      _finishOperation();
    }
  }

  Future<bool> scanIdentity(
    String identity, {
    List<String> associatedUsernames = const [],
    bool consentSelfAudit = true,
  }) async {
    if (_disposed || _isLoading) return false;
    _isLoading = true;
    _error = null;
    _failedScanIdentity = null;
    _scanningStage = 'Iniciando análisis de identidad…';
    _notify();

    try {
      _scanningStage = 'Consultando fuentes y registros públicos…';
      _notify();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (_disposed) return false;

      _scanningStage = 'Correlacionando niveles de exposición…';
      _notify();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (_disposed) return false;

      _scanningStage = 'Generando diagnóstico de huella digital…';
      _notify();

      final profile = await _repository.scanIdentity(
        identity,
        associatedUsernames: associatedUsernames,
        consentSelfAudit: consentSelfAudit,
      );
      if (_disposed) return false;
      _profile = profile;
      await onScanCompleted?.call(profile);
      return !_disposed;
    } catch (e) {
      if (!_disposed) {
        _failedScanIdentity = identity;
        _error = e is FormatException
            ? e.message
            : 'Ocurrió un error al realizar el escaneo.';
      }
      return false;
    } finally {
      _finishOperation();
    }
  }

  void _finishOperation() {
    if (_disposed) return;
    _isLoading = false;
    _scanningStage = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _failedScanIdentity = null;
    super.dispose();
  }
}
