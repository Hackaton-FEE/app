import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../domain/auth_tokens.dart';
import '../domain/scan_capability.dart';
import '../domain/session_info.dart';
import '../domain/user_profile.dart';
import 'token_storage.dart';

class AuthApiException implements Exception {
  const AuthApiException({
    required this.message,
    this.code,
    this.statusCode,
  });

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

  /// Registra una cuenta nueva con correo y contraseña (12–128 caracteres).
  ///
  /// Nota de contrato: Devuelve 201 con los datos públicos del perfil, pero
  /// NO entrega tokens de sesión automáticamente.
  Future<UserProfile> register({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'email': cleanEmail, 'password': password}),
        )
        .timeout(_timeout);

    if (response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      return UserProfile.fromJson(data);
    }

    throw _parseError(response);
  }

  /// Inicia sesión con correo y contraseña. Devuelve tokens y guarda
  /// el refresh en almacenamiento seguro y el access en memoria.
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'email': cleanEmail, 'password': password}),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      final tokens = AuthTokens.fromJson(data);
      tokenStorage.accessToken = tokens.accessToken;
      await tokenStorage.saveRefreshToken(tokens.refreshToken);
      return tokens;
    }

    throw _parseError(response);
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
      final data = _decodeBody(response) as Map<String, dynamic>;
      final tokens = AuthTokens.fromJson(data);
      tokenStorage.accessToken = tokens.accessToken;
      await tokenStorage.saveRefreshToken(tokens.refreshToken);
      return tokens;
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
      final data = _decodeBody(response) as Map<String, dynamic>;
      final tokens = AuthTokens.fromJson(data);
      tokenStorage.accessToken = tokens.accessToken;
      await tokenStorage.saveRefreshToken(tokens.refreshToken);
      return tokens;
    }
    throw _parseError(response);
  }

  /// Renueva los tokens de sesión de manera atómica y serializada.
  /// Si múltiples peticiones coinciden, comparten una única llamada
  /// para evitar reutilizar y revocar el refresh_token.
  Future<AuthTokens?> refreshTokens() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<AuthTokens?>();
    _refreshCompleter = completer;

    try {
      final currentRefresh = await tokenStorage.readRefreshToken();
      if (currentRefresh == null || currentRefresh.isEmpty) {
        completer.complete(null);
        return null;
      }

      // En v0.2.0 la ruta es /auth/token/refresh; con fallback a /auth/refresh para compatibilidad
      var response = await _client
          .post(
            Uri.parse('$baseUrl/auth/token/refresh'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'User-Agent': 'fee_app/0.1.0',
            },
            body: jsonEncode({'refresh_token': currentRefresh}),
          )
          .timeout(_timeout);

      if (response.statusCode == 404) {
        response = await _client
            .post(
              Uri.parse('$baseUrl/auth/refresh'),
              headers: {
                'Content-Type': 'application/json; charset=utf-8',
                'User-Agent': 'fee_app/0.1.0',
              },
              body: jsonEncode({'refresh_token': currentRefresh}),
            )
            .timeout(_timeout);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        final tokens = AuthTokens.fromJson(data);
        tokenStorage.accessToken = tokens.accessToken;
        await tokenStorage.saveRefreshToken(tokens.refreshToken);
        completer.complete(tokens);
        return tokens;
      } else {
        // Refresh inválido o expirado: descartar credenciales
        await tokenStorage.clearAll();
        completer.complete(null);
        return null;
      }
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }

  /// Consulta el perfil del usuario autenticado en `GET /auth/me`.
  Future<UserProfile> getMe() async {
    final response = await _authenticatedRequest('GET', '/auth/me');
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
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

  /// Consulta las sesiones activas propias en `GET /auth/sessions`.
  Future<List<SessionInfo>> getSessions() async {
    final response = await _authenticatedRequest('GET', '/auth/sessions');
    if (response.statusCode == 200) {
      final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return list
          .map((item) => SessionInfo.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw _parseError(response);
  }

  /// Revoca una sesión por su UUID en `DELETE /auth/sessions/{id}`.
  Future<void> revokeSession(String sessionId) async {
    final response = await _authenticatedRequest(
      'DELETE',
      '/auth/sessions/$sessionId',
    );
    if (response.statusCode == 204) {
      return;
    }
    throw _parseError(response);
  }

  /// Cambia la contraseña y revoca todas las sesiones en `POST /auth/change-password`.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _authenticatedRequest(
      'POST',
      '/auth/change-password',
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    if (response.statusCode == 204) {
      // Tras cambio de contraseña el servidor revoca todas las sesiones
      await tokenStorage.clearAll();
      return;
    }
    throw _parseError(response);
  }

  /// Consulta los proveedores de escaneo previstos en `GET /scans/capabilities`.
  Future<List<ScanCapabilityProvider>> getScanCapabilities() async {
    final response = await _authenticatedRequest('GET', '/scans/capabilities');
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      final list = (data['providers'] as List<dynamic>? ?? []);
      return list
          .map((item) =>
              ScanCapabilityProvider.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw _parseError(response);
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
    try {
      final decoded = _decodeBody(response);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is Map<String, dynamic>) {
          final code = detail['code'] as String?;
          final message = detail['message'] as String? ?? 'Error en el servidor.';
          return AuthApiException(
            message: _localizeMessage(code, message),
            code: code,
            statusCode: response.statusCode,
          );
        } else if (detail is String) {
          return AuthApiException(
            message: detail,
            statusCode: response.statusCode,
          );
        } else if (detail is List) {
          // Error 422 de validación de FastAPI
          final messages = detail
              .whereType<Map<String, dynamic>>()
              .map((e) => e['msg']?.toString())
              .where((m) => m != null)
              .join(', ');
          return AuthApiException(
            message: messages.isNotEmpty
                ? 'Datos inválidos: $messages'
                : 'Formato de datos no válido.',
            code: 'validation_error',
            statusCode: response.statusCode,
          );
        }
      }
    } catch (_) {
      // Ignorar fallo de parseo JSON y usar mensaje genérico
    }

    return AuthApiException(
      message: switch (response.statusCode) {
        400 => 'Petición inválida.',
        401 => 'Credenciales inválidas o sesión no autorizada.',
        403 => 'Acceso denegado.',
        404 => 'Recurso no encontrado.',
        409 => 'Ya existe una cuenta con este correo.',
        422 => 'La contraseña debe tener entre 12 y 128 caracteres.',
        429 => 'Demasiados intentos. Inténtalo más tarde.',
        500 || 502 || 503 => 'Error en los servicios del servidor.',
        _ => 'Error inesperado (${response.statusCode}).',
      },
      statusCode: response.statusCode,
    );
  }

  String _localizeMessage(String? code, String fallback) {
    return switch (code) {
      'invalid_credentials' => 'Correo o contraseña incorrectos.',
      'registration_conflict' => 'Ya existe una cuenta registrada con este correo.',
      'invalid_refresh_token' => 'Tu sesión ha caducado. Vuelve a iniciar sesión.',
      'session_not_found' => 'La sesión no fue encontrada o ya expiró.',
      'rate_limited' => 'Demasiadas solicitudes. Espera un momento.',
      'storage_unavailable' => 'Base de datos no disponible temporalmente.',
      'unknown_credential' =>
          'No se encontró una Bóveda registrada con esta credencial. Por favor crea tu bóveda primero.',
      'invalid_credential' =>
          'La credencial de la bóveda no pudo ser validada. Intenta nuevamente.',
      'invalid_challenge' =>
          'El reto de seguridad ha caducado. Inténtalo de nuevo.',
      'no_passkey_found' =>
          'No se encontró una Bóveda registrada en este dispositivo. Por favor crea una bóveda primero.',
      _ => fallback,
    };
  }
}
