import 'package:flutter/foundation.dart';

import '../domain/identity_profile.dart';
import '../domain/identity_profile_repository.dart';

/// Manages identity profile configuration and onboarding state per account.
class IdentityProfileController extends ChangeNotifier {
  IdentityProfileController(
    this._repository, {
    required this.accountId,
    this.isDemo = false,
  });

  final IdentityProfileRepository _repository;
  final String accountId;
  final bool isDemo;

  IdentityProfile? _profile;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoaded = false;
  bool _disposed = false;
  String? _error;

  IdentityProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isLoaded => _isLoaded;
  String? get error => _error;

  /// True if a non-demo account has not yet completed profile setup.
  bool get needsOnboarding {
    if (isDemo) return false;
    if (!_isLoaded) return false;
    return _profile == null || !_profile!.hasCompletedOnboarding;
  }

  Future<void> load() async {
    if (_disposed || _isLoading || _isSaving) return;
    _isLoading = true;
    _error = null;
    _notify();

    try {
      final loaded = await _repository.getProfile(accountId);
      if (_disposed) return;
      _profile = loaded;
      _isLoaded = true;
    } catch (e) {
      if (!_disposed) {
        _error = 'No se pudo cargar el perfil de identidad.';
        _isLoaded = true;
      }
    } finally {
      if (!_disposed) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<bool> save(IdentityProfile profile) async {
    if (_disposed || _isSaving) return false;
    _isSaving = true;
    _error = null;
    _notify();

    try {
      await _repository.saveProfile(profile);
      if (_disposed) return false;
      _profile = profile;
      _isLoaded = true;
      return true;
    } catch (e) {
      if (!_disposed) {
        _error =
            e is FormatException ? e.message : 'Error al guardar el perfil.';
      }
      return false;
    } finally {
      if (!_disposed) {
        _isSaving = false;
        _notify();
      }
    }
  }

  Future<bool> skipOnboarding({String? identifier, String? email}) async {
    final effectiveId = (identifier?.trim().isNotEmpty == true)
        ? identifier!.trim()
        : (email?.trim() ?? '');
    final defaultProfile = IdentityProfile(
      accountId: accountId,
      mainIdentifier: effectiveId,
      associatedEmail: effectiveId.contains('@') ? effectiveId : null,
      hasCompletedOnboarding: true,
      consentSelfAudit: true,
      createdAt: DateTime.now(),
    );
    return save(defaultProfile);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
