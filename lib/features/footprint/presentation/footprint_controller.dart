import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/footprint_item.dart';
import '../domain/footprint_profile.dart';
import '../domain/footprint_repository.dart';

class FootprintController extends ChangeNotifier {
  FootprintController(this._repository);

  final FootprintRepository _repository;

  FootprintProfile? _profile;
  bool _isLoading = false;
  String? _error;
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
    return _profile!.items
        .where((item) => item.category == _selectedCategory)
        .toList();
  }

  void setCategoryFilter(FootprintCategory? category) {
    if (_selectedCategory == category) {
      _selectedCategory = null;
    } else {
      _selectedCategory = category;
    }
    notifyListeners();
  }

  Future<void> loadProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _repository.getProfile();
    } catch (e) {
      _error = 'No se pudo cargar la información de huella digital.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> scanIdentity(String identity) async {
    if (_isLoading) return false;
    _isLoading = true;
    _error = null;
    _scanningStage = 'Preparando análisis de ejemplo…';
    notifyListeners();

    try {
      _scanningStage = 'Preparando perfiles de ejemplo…';
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      _scanningStage = 'Organizando datos simulados…';
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      _scanningStage = 'Construyendo tu vista de ejemplo…';
      notifyListeners();

      _profile = await _repository.scanIdentity(identity);
      _scanningStage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _scanningStage = null;
      _isLoading = false;
      _error = e is FormatException
          ? e.message
          : 'Ocurrió un error al realizar el escaneo.';
      notifyListeners();
      return false;
    }
  }
}
