import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Interfaz para adaptadores de autenticación nativa por Passkey (FIDO2 / WebAuthn).
abstract class PasskeyAuthenticator {
  /// Genera una nueva passkey con biometría a partir de las opciones del backend.
  Future<Map<String, dynamic>> createCredential(
    Map<String, dynamic> publicKeyOptions,
  );

  /// Solicita la aserción y firma biométrica para una passkey existente.
  Future<Map<String, dynamic>> getCredential(
    Map<String, dynamic> publicKeyOptions,
  );
}

/// Autenticador por software para pruebas, simuladores y fallback controlado.
class SoftPasskeyAuthenticator implements PasskeyAuthenticator {
  SoftPasskeyAuthenticator({
    this.origin = 'https://backosisnt.ici-labs.com',
  });

  final String origin;
  final _uuid = const Uuid();

  @override
  Future<Map<String, dynamic>> createCredential(
    Map<String, dynamic> publicKeyOptions,
  ) async {
    final challenge = publicKeyOptions['challenge'] as String? ?? '';
    final credentialId = base64UrlEncode(utf8.encode('passkey_${_uuid.v4()}'));

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
        'attestationObject': base64UrlEncode(utf8.encode('attestation_mock')),
      },
    };
  }

  @override
  Future<Map<String, dynamic>> getCredential(
    Map<String, dynamic> publicKeyOptions,
  ) async {
    final challenge = publicKeyOptions['challenge'] as String? ?? '';
    final credentialId = base64UrlEncode(utf8.encode('passkey_${_uuid.v4()}'));

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
        'authenticatorData': base64UrlEncode(utf8.encode('authdata_mock')),
        'signature': base64UrlEncode(utf8.encode('sig_mock')),
      },
    };
  }

  static String base64UrlEncode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
