import 'package:flutter/foundation.dart';

import '../domain/account_repository.dart';
import '../domain/local_account.dart';

/// A local session stays in memory and never signs in automatically on launch.
class AccountsController extends ChangeNotifier {
  AccountsController(this._repository);

  final AccountRepository _repository;
  List<LocalAccount> _accounts = const [];
  LocalAccount? _activeAccount;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _loadInProgress = false;
  bool _disposed = false;
  String? _loadError;
  String? _actionError;

  List<LocalAccount> get accounts => _accounts;
  LocalAccount? get activeAccount => _activeAccount;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get loadError => _loadError;
  String? get actionError => _actionError;
  String? get error => _loadError ?? _actionError;

  Future<void> load() async {
    if (_loadInProgress || _isSaving || _disposed) return;
    _loadInProgress = true;
    _isLoading = true;
    _loadError = null;
    _actionError = null;
    _notify();
    try {
      final accounts = await _repository.listAccounts();
      if (_disposed) return;
      _accounts = List.unmodifiable(accounts);
      if (_activeAccount case final active?) {
        _activeAccount = null;
        for (final account in accounts) {
          if (account.id == active.id) _activeAccount = account;
        }
      }
    } catch (error) {
      if (!_disposed) _loadError = _errorMessage(error);
    } finally {
      _loadInProgress = false;
      if (!_disposed) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<bool> addAccount({required String name, required String email}) async {
    if (_disposed || _isLoading || _isSaving || _loadError != null) {
      return false;
    }
    _isSaving = true;
    _actionError = null;
    _notify();
    try {
      final saved = await _repository.addAccount(name: name, email: email);
      if (_disposed) return false;
      final accounts = [..._accounts, saved]
        ..sort((first, second) {
          final byName = first.name.toLowerCase().compareTo(
            second.name.toLowerCase(),
          );
          return byName == 0 ? first.id.compareTo(second.id) : byName;
        });
      _accounts = List.unmodifiable(accounts);
      _activeAccount = saved;
      return true;
    } catch (error) {
      if (!_disposed) _actionError = _errorMessage(error);
      return false;
    } finally {
      if (!_disposed) {
        _isSaving = false;
        _notify();
      }
    }
  }

  bool selectAccount(LocalAccount account) {
    if (_disposed || _isLoading || _isSaving || _loadError != null) {
      return false;
    }
    for (final saved in _accounts) {
      if (saved.id == account.id) {
        _activeAccount = saved;
        _actionError = null;
        _notify();
        return true;
      }
    }
    _actionError =
        'Esta cuenta ya no está disponible. Vuelve a cargar la lista.';
    _notify();
    return false;
  }

  void signOut() {
    if (_disposed || _isSaving) return;
    _activeAccount = null;
    _actionError = null;
    _notify();
  }

  String _errorMessage(Object error) {
    if (error is AccountRepositoryException) {
      return switch (error.reason) {
        AccountRepositoryExceptionReason.unavailable =>
          'No pudimos cargar las cuentas de ejemplo. Inténtalo de nuevo.',
        AccountRepositoryExceptionReason.duplicateEmail => 'Ya agregaste una cuenta con ese correo. Puedes elegirla en la lista.',
      };
    }
    if (error is FormatException) {
      return 'Revisa el nombre y el correo de la cuenta.';
    }
    return 'No pudimos completar la operación. Inténtalo de nuevo.';
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
