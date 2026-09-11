import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:passkeys/authenticator.dart' as native;
import 'package:passkeys/types.dart' as native;

import 'auth_api_client.dart';

/// Frontera con el autenticador del sistema operativo (FIDO2 / WebAuthn).
abstract class PasskeyAuthenticator {
  Future<Map<String, dynamic>> createCredential(
    Map<String, dynamic> publicKeyOptions,
  );

  Future<Map<String, dynamic>> getCredential(
    Map<String, dynamic> publicKeyOptions,
  );

  /// Solo indica si esta app recuerda un ID nativo usado anteriormente.
  /// No demuestra que el gestor del sistema conserve la llave privada.
  Future<bool> hasStoredCredential();
  Future<String?> getStoredCredentialId();

  /// Elimina la referencia local; la passkey se administra en el sistema.
  Future<void> clearStoredCredential();
}

/// Delega generación y firma al proveedor nativo. Nunca fabrica credenciales.
class NativePasskeyAuthenticator implements PasskeyAuthenticator {
  NativePasskeyAuthenticator({
    native.PasskeyAuthenticatorInterface? platform,
    FlutterSecureStorage? storage,
    this.storageKey = 'fee.auth.v2.native_passkey_credential_id',
  }) : _platform = platform ?? native.PasskeyAuthenticator(),
       _storage =
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

  final native.PasskeyAuthenticatorInterface _platform;
  final FlutterSecureStorage _storage;
  final String storageKey;
  String? _cachedCredentialId;

  @override
  Future<Map<String, dynamic>> createCredential(
    Map<String, dynamic> publicKeyOptions,
  ) async {
    try {
      final request = native.RegisterRequestType.fromJson(
        _withCredentialTransports(publicKeyOptions, 'excludeCredentials'),
      );
      final result = await _platform.register(request);
      if (result.id.isEmpty ||
          result.rawId.isEmpty ||
          result.attestationObject.isEmpty ||
          result.clientDataJSON.isEmpty) {
        throw const AuthApiException(
          message: 'El dispositivo no devolvió una llave de acceso válida.',
          code: 'invalid_passkey_response',
        );
      }
      await _remember(result.id);
      return result.toJson();
    } catch (error, stackTrace) {
      throw _authError(error, stackTrace);
    }
  }

  @override
  Future<Map<String, dynamic>> getCredential(
    Map<String, dynamic> publicKeyOptions,
  ) async {
    try {
      final request = native.AuthenticateRequestType.fromJson(
        _withCredentialTransports(publicKeyOptions, 'allowCredentials'),
        // Permite elegir también una llave sincronizada o de otro dispositivo.
        preferImmediatelyAvailableCredentials: false,
      );
      final result = await _platform.authenticate(request);
      if (result.id.isEmpty ||
          result.rawId.isEmpty ||
          result.signature.isEmpty ||
          result.authenticatorData.isEmpty ||
          result.clientDataJSON.isEmpty) {
        throw const AuthApiException(
          message: 'El dispositivo no devolvió una firma válida.',
          code: 'invalid_passkey_response',
        );
      }
      await _remember(result.id);
      return result.toJson();
    } catch (error, stackTrace) {
      throw _authError(error, stackTrace);
    }
  }

  // WebAuthn permite omitir transports; el DTO del plugin exige una lista.
  Map<String, dynamic> _withCredentialTransports(
    Map<String, dynamic> options,
    String field,
  ) {
    final credentials = options[field] as List<dynamic>?;
    return {
      ...options,
      if (credentials != null)
        field: [
          for (final credential in credentials)
            {
              ...credential as Map<String, dynamic>,
              'transports': credential['transports'] ?? <String>[],
            },
        ],
    };
  }

  Future<void> _remember(String id) async {
    try {
      await _storage.write(key: storageKey, value: id);
      _cachedCredentialId = id;
    } catch (_) {
      throw _storageError;
    }
  }

  @override
  Future<bool> hasStoredCredential() async =>
      (await getStoredCredentialId())?.isNotEmpty ?? false;

  @override
  Future<String?> getStoredCredentialId() async {
    if (_cachedCredentialId != null) return _cachedCredentialId;
    try {
      return _cachedCredentialId = await _storage.read(key: storageKey);
    } catch (_) {
      throw _storageError;
    }
  }

  @override
  Future<void> clearStoredCredential() async {
    try {
      await _storage.delete(key: storageKey);
      _cachedCredentialId = null;
    } catch (_) {
      throw _storageError;
    }
  }

  static const _storageError = AuthApiException(
    message:
        'No se pudo actualizar la referencia local de la llave. Reintenta.',
    code: 'passkey_storage_error',
  );

  AuthApiException _authError(Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      final code = switch (error) {
        native.UnhandledAuthenticatorException e => e.code,
        PlatformException e => e.code,
        _ => '',
      };
      debugPrint('FEE passkey failure: ${error.runtimeType} [$code]');
      if (error case native.UnhandledAuthenticatorException e) {
        final reason = (e.message ?? '')
            .replaceAll(RegExp(r'\{[\s\S]*\}'), '[request omitted]')
            .replaceAll(RegExp(r'\S+@\S+'), '[address omitted]')
            .replaceAll(RegExp(r'[A-Za-z0-9_-]{24,}'), '[identifier omitted]');
        debugPrint('FEE passkey native reason: $reason');
      }
      debugPrint(stackTrace.toString().split('\n').take(6).join('\n'));
    }
    if (error is AuthApiException) return error;
    if (error is native.PasskeyAuthCancelledException) {
      return const AuthApiException(
        message: 'Se canceló el acceso. Puedes volver a intentarlo.',
        code: 'passkey_cancelled',
      );
    }
    if (error is native.NoCredentialsAvailableException) {
      return const AuthApiException(
        message: 'No se encontró una llave de acceso. Elige otra llave o crea una bóveda.',
        code: 'no_passkey_found',
      );
    }
    if (error is native.DomainNotAssociatedException ||
        (error is native.UnhandledAuthenticatorException &&
            (error.message?.contains('RP ID cannot be validated') ?? false))) {
      return const AuthApiException(
        message: 'Esta versión de la app aún no está asociada al servicio.',
        code: 'passkey_domain_unavailable',
      );
    }
    if (error is native.MissingGoogleSignInException ||
        error is native.SyncAccountNotAvailableException ||
        error is native.NoCreateOptionException) {
      return const AuthApiException(
        message: 'Configura un gestor de llaves de acceso y el bloqueo de pantalla en tu dispositivo.',
        code: 'passkey_setup_required',
      );
    }
    if (error is native.ExcludeCredentialsCanNotBeRegisteredException) {
      return const AuthApiException(
        message: 'Esta llave ya existe. Usa Iniciar sesión.',
        code: 'passkey_already_exists',
      );
    }
    if (error is native.TimeoutException) {
      return const AuthApiException(
        message: 'La solicitud de acceso venció. Vuelve a intentarlo.',
        code: 'passkey_timeout',
      );
    }
    return const AuthApiException(
      message:
          'No se pudo usar una llave de acceso en este dispositivo. Reintenta.',
      code: 'passkey_unavailable',
    );
  }
}
