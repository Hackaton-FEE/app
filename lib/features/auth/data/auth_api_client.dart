import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/auth_tokens.dart';
import '../domain/user_profile.dart';
import 'token_storage.dart';

class AuthApiException implements Exception {
  const AuthApiException({required this.message, this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => 'AuthApiException($code, $statusCode): $message';
}

class AuthApiClient {
  AuthApiClient({
    this.baseUrl = 'https://backosisnt.ici-labs.com/api/v1',
    required this.tokenStorage,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  final String baseUrl;
  final TokenStorage tokenStorage;
  final http.Client _client;

  Completer<AuthTokens?>? _refreshCompleter;

  static const _timeout = Duration(seconds: 15);

  /// Comprueba la salud y disponibilidad del servicio `/health`.
  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['status'] == 'ok';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Solicita opciones de registro FIDO2 en `POST /auth/passkey/registration/options`.
  Future<Map<String, dynamic>> getRegistrationOptions({
    String label = 'Mi Bóveda FEE',
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/passkey/registration/options'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'User-Agent': 'fee_app/0.1.0',
          },
          body: jsonEncode({'label': label}),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return _decodeBody(response) as Map<String, dynamic>;
    }
    throw _parseError(response);
  }

  /// Valida la credencial creada por el autenticador en `POST /auth/passkey/registration/verify`.
  Future<AuthTokens> verifyRegistration({
    required String challengeToken,
    required Map<String, dynamic> credential,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/passkey/registration/verify'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'User-Agent': 'fee_app/0.1.0',
          },
          body: jsonEncode({
            'challenge_token': challengeToken,
            'credential': credential,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return _saveSession(response);
    }
    throw _parseError(response);
  }

  /// Solicita el reto para inicio de sesión en `POST /auth/passkey/authentication/options`.
  Future<Map<String, dynamic>> getAuthenticationOptions() async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/passkey/authentication/options'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'User-Agent': 'fee_app/0.1.0',
          },
          body: jsonEncode({}),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return _decodeBody(response) as Map<String, dynamic>;
    }
    throw _parseError(response);
  }

  /// Valida la aserción y firma biométrica en `POST /auth/passkey/authentication/verify`.
  Future<AuthTokens> verifyAuthentication({
    required String challengeToken,
    required Map<String, dynamic> credential,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/passkey/authentication/verify'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'User-Agent': 'fee_app/0.1.0',
          },
          body: jsonEncode({
            'challenge_token': challengeToken,
            'credential': credential,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return _saveSession(response);
    }
    throw _parseError(response);
  }

  /// Abre una sesión aislada sin registro ni ceremonia nativa.
  Future<AuthTokens> createTestingSession() async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/testing/session'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'User-Agent': 'fee_app/0.1.0',
          },
          body: '{}',
        )
        .timeout(_timeout);
    if (response.statusCode != 201) throw _parseError(response);
    return _saveSession(response);
  }

  /// Renueva los tokens de sesión de manera atómica y serializada.
  /// Si múltiples peticiones coinciden, comparten una única llamada
  /// para evitar reutilizar y revocar el refresh_token.
  Future<AuthTokens?> refreshTokens() {
    if (_refreshCompleter != null) return _refreshCompleter!.future;
    final completer = Completer<AuthTokens?>();
    _refreshCompleter = completer;
    unawaited(
      _refreshTokens()
          .then(completer.complete, onError: completer.completeError)
          .whenComplete(() => _refreshCompleter = null),
    );
    return completer.future;
  }

  Future<AuthTokens?> _refreshTokens() async {
    final refresh = await tokenStorage.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return null;
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/token/refresh'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'refresh_token': refresh}),
        )
        .timeout(_timeout);
    if (response.statusCode == 401) {
      await tokenStorage.clearAll();
      return null;
    }
    if (response.statusCode != 200) throw _parseError(response);
    return _saveSession(response);
  }

  Future<AuthTokens> _saveSession(http.Response response) async {
    final tokens = AuthTokens.fromJson(
      _decodeBody(response) as Map<String, dynamic>,
    );
    await tokenStorage.saveRefreshToken(tokens.refreshToken);
    tokenStorage.accessToken = tokens.accessToken;
    return tokens;
  }

  /// Consulta el perfil del usuario autenticado en `GET /auth/me`.
  Future<UserProfile> getMe() async {
    final response = await _authenticatedRequest('GET', '/auth/me');
    if (response.statusCode == 200) {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return UserProfile.fromJson(data);
    }
    throw _parseError(response);
  }

  /// Cierra la sesión activa revocándola en el servidor (`POST /auth/logout`)
  /// y eliminando las credenciales locales.
  Future<void> logout() async {
    try {
      final token = tokenStorage.accessToken;
      final refresh = await tokenStorage.readRefreshToken();
      final headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'User-Agent': 'fee_app/0.1.0',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      await _client
          .post(
            Uri.parse('$baseUrl/auth/logout'),
            headers: headers,
            body: jsonEncode({'refresh_token': refresh ?? ''}),
          )
          .timeout(_timeout);
    } catch (_) {
      // Ignorar errores de red para asegurar limpieza local
    } finally {
      await tokenStorage.clearAll();
    }
  }

  /// Realiza una petición autenticada con reintento automático si expira el token.
  Future<http.Response> _authenticatedRequest(
    String method,
    String path, {
    String? body,
  }) async {
    var token = tokenStorage.accessToken;
    if (token == null || token.isEmpty) {
      final refreshed = await refreshTokens();
      token = refreshed?.accessToken;
      if (token == null) {
        throw const AuthApiException(
          message: 'No hay una sesión activa.',
          code: 'unauthorized',
          statusCode: 401,
        );
      }
    }

    http.Response response = await _sendRequest(method, path, token, body);

    // Si devuelve 401, intentamos una única renovación de token y reintento
    if (response.statusCode == 401) {
      final refreshed = await refreshTokens();
      if (refreshed != null) {
        response = await _sendRequest(
          method,
          path,
          refreshed.accessToken,
          body,
        );
      } else {
        throw const AuthApiException(
          message: 'Tu sesión ha caducado. Vuelve a iniciar sesión.',
          code: 'session_expired',
          statusCode: 401,
        );
      }
    }

    return response;
  }

  Future<http.Response> _sendRequest(
    String method,
    String path,
    String token,
    String? body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'User-Agent': 'fee_app/0.1.0',
      'Authorization': 'Bearer $token',
    };

    switch (method.toUpperCase()) {
      case 'GET':
        return _client.get(uri, headers: headers).timeout(_timeout);
      case 'POST':
        return _client
            .post(uri, headers: headers, body: body)
            .timeout(_timeout);
      case 'DELETE':
        return _client.delete(uri, headers: headers).timeout(_timeout);
      default:
        throw UnsupportedError('Método HTTP no soportado: $method');
    }
  }

  dynamic _decodeBody(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return jsonDecode(response.body);
    }
  }

  AuthApiException _parseError(http.Response response) {
    String? code;
    try {
      final decoded = _decodeBody(response);
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type'];
        final detail = decoded['detail'];
        code = type is String ? type.split('/').last : null;
        if (detail is Map<String, dynamic>) code ??= detail['code'] as String?;
      }
    } catch (_) {
      // Error messages do not echo identifiers or remote response bodies.
    }
    return AuthApiException(
      message: code == 'testing-access-disabled'
          ? 'El acceso de pruebas no está habilitado en el servidor. Intenta más tarde.'
          : switch (response.statusCode) {
              400 || 422 => 'No se pudo validar la solicitud. Revisa los datos e inténtalo de nuevo.',
              401 => 'Tu sesión o llave de acceso no pudo validarse. Inicia sesión de nuevo.',
              403 => 'Acceso denegado.',
              404 => 'El servicio solicitado no está disponible.',
              409 =>
                'La solicitud entra en conflicto con un registro existente.',
              429 => 'Demasiados intentos. Inténtalo más tarde.',
              _ => 'No se pudo completar la consulta al servidor.',
            },
      code: code,
      statusCode: response.statusCode,
    );
  }
}
