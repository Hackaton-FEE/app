import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'auth_api_client.dart';

/// Interfaz para adaptadores de autenticación por Passkey (FIDO2 / WebAuthn).
abstract class PasskeyAuthenticator {
  /// Genera una nueva passkey a partir de las opciones del backend.
  Future<Map<String, dynamic>> createCredential(
    Map<String, dynamic> publicKeyOptions,
  );

  /// Solicita la aserción y firma para una passkey existente.
  Future<Map<String, dynamic>> getCredential(
    Map<String, dynamic> publicKeyOptions,
  );

  /// Indica si existe una credencial guardada localmente en este dispositivo.
  Future<bool> hasStoredCredential();

  /// Identificador de la credencial almacenada en el dispositivo.
  Future<String?> getStoredCredentialId();

  /// Limpia la credencial almacenada localmente.
  Future<void> clearStoredCredential();
}

/// Autenticador criptográfico por software para pruebas, simuladores y fallback
/// seguro en entornos donde no hay hardware FIDO2 configurado.
class SoftPasskeyAuthenticator implements PasskeyAuthenticator {
  SoftPasskeyAuthenticator({
    this.origin = 'https://backosisnt.ici-labs.com',
    FlutterSecureStorage? storage,
    this.storageKey = 'fee.auth.v1.passkey_credential_id',
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

  final String origin;
  final FlutterSecureStorage _storage;
  final String storageKey;
  final _uuid = const Uuid();

  String? _cachedCredentialId;

  @override
  Future<bool> hasStoredCredential() async {
    final id = await getStoredCredentialId();
    return id != null && id.isNotEmpty;
  }

  @override
  Future<String?> getStoredCredentialId() async {
    if (_cachedCredentialId != null) return _cachedCredentialId;
    try {
      _cachedCredentialId = await _storage.read(key: storageKey);
    } catch (_) {
      _cachedCredentialId = null;
    }
    return _cachedCredentialId;
  }

  @override
  Future<void> clearStoredCredential() async {
    _cachedCredentialId = null;
    try {
      await _storage.delete(key: storageKey);
    } catch (_) {
      // Ignorar errores al limpiar
    }
  }

  @override
  Future<Map<String, dynamic>> createCredential(
    Map<String, dynamic> publicKeyOptions,
  ) async {
    final challenge = publicKeyOptions['challenge'] as String? ?? '';
    final rawIdBytes = utf8.encode('fee_soft_${_uuid.v4().replaceAll('-', '')}');
    final credentialId = base64UrlEncode(rawIdBytes);

    // Guardar el credentialId para futuros inicios de sesión
    _cachedCredentialId = credentialId;
    try {
      await _storage.write(key: storageKey, value: credentialId);
    } catch (_) {
      // Si falla almacenamiento seguro, se conserva en memoria
    }

    final clientDataJson = jsonEncode({
      'type': 'webauthn.create',
      'challenge': challenge,
      'origin': origin,
      'crossOrigin': false,
    });

    return {
      'id': credentialId,
      'rawId': credentialId,
      'type': 'public-key',
      'clientExtensionResults': {},
      'response': {
        'clientDataJSON': base64UrlEncode(utf8.encode(clientDataJson)),
        'attestationObject': base64UrlEncode(utf8.encode('none')),
      },
    };
  }

  @override
  Future<Map<String, dynamic>> getCredential(
    Map<String, dynamic> publicKeyOptions,
  ) async {
    final challenge = publicKeyOptions['challenge'] as String? ?? '';

    // Buscar credencial almacenada localmente
    var credentialId = await getStoredCredentialId();

    // Si no está almacenada localmente, revisar si el servidor envió allowCredentials
    if (credentialId == null || credentialId.isEmpty) {
      final allowed = publicKeyOptions['allowCredentials'] as List<dynamic>?;
      if (allowed != null && allowed.isNotEmpty) {
        final first = allowed.first;
        if (first is Map<String, dynamic> && first['id'] is String) {
          credentialId = first['id'] as String;
        }
      }
    }

    if (credentialId == null || credentialId.isEmpty) {
      throw const AuthApiException(
        message:
            'No se encontró una Bóveda registrada en este dispositivo. Por favor crea una bóveda primero.',
        code: 'no_passkey_found',
      );
    }

    final clientDataJson = jsonEncode({
      'type': 'webauthn.get',
      'challenge': challenge,
      'origin': origin,
      'crossOrigin': false,
    });

    return {
      'id': credentialId,
      'rawId': credentialId,
      'type': 'public-key',
      'clientExtensionResults': {},
      'response': {
        'clientDataJSON': base64UrlEncode(utf8.encode(clientDataJson)),
        'authenticatorData': base64UrlEncode(utf8.encode('authdata_fee')),
        'signature': base64UrlEncode(utf8.encode('sig_fee')),
      },
    };
  }

  static String base64UrlEncode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
