import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStorage {
  Future<String?> readRefreshToken();
  Future<void> saveRefreshToken(String token);
  Future<void> clearRefreshToken();

  String? get accessToken;
  set accessToken(String? token);

  Future<void> clearAll();
}

/// Almacenamiento que guarda el `refresh_token` en almacenamiento seguro
/// cifrado del dispositivo (Keychain / Keystore) y conserva el `access_token`
/// únicamente en memoria por seguridad.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({
    FlutterSecureStorage? storage,
    this.refreshKey = 'fee.auth.v1.refresh_token',
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(
               resetOnError: false,
               storageNamespace: 'fee_auth',
             ),
             iOptions: IOSOptions(
               accountName: 'org.hackatonfee.feeApp.auth',
               accessibility: KeychainAccessibility.unlocked_this_device,
               synchronizable: false,
             ),
           );

  final FlutterSecureStorage _storage;
  final String refreshKey;
  String? _accessToken;

  @override
  String? get accessToken => _accessToken;

  @override
  set accessToken(String? token) {
    _accessToken = token;
  }

  @override
  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: refreshKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: refreshKey, value: token);
  }

  @override
  Future<void> clearRefreshToken() async {
    try {
      await _storage.delete(key: refreshKey);
    } catch (_) {
      // Ignorar errores en limpieza
    }
  }

  @override
  Future<void> clearAll() async {
    _accessToken = null;
    await clearRefreshToken();
  }
}

/// Implementación en memoria de [TokenStorage] para pruebas unitarias.
class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage({String? initialRefreshToken, String? initialAccessToken})
      : _refreshToken = initialRefreshToken,
        _accessToken = initialAccessToken;

  String? _refreshToken;
  String? _accessToken;

  @override
  String? get accessToken => _accessToken;

  @override
  set accessToken(String? token) {
    _accessToken = token;
  }

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<void> saveRefreshToken(String token) async {
    _refreshToken = token;
  }

  @override
  Future<void> clearRefreshToken() async {
    _refreshToken = null;
  }

  @override
  Future<void> clearAll() async {
    _refreshToken = null;
    _accessToken = null;
  }
}
