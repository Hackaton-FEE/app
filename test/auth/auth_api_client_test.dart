import 'dart:convert';
import 'package:fee_app/features/auth/data/auth_api_client.dart';
import 'package:fee_app/features/auth/data/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late InMemoryTokenStorage tokenStorage;

  setUp(() {
    tokenStorage = InMemoryTokenStorage();
  });

  group('AuthApiClient', () {
    test('checkHealth returns true when server responds 200 ok', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/health');
        return http.Response(
          jsonEncode({'status': 'ok', 'service': 'fee-server'}),
          200,
        );
      });

      final client = AuthApiClient(
        baseUrl: 'https://example.com/api/v1',
        tokenStorage: tokenStorage,
        httpClient: mockClient,
      );

      expect(await client.checkHealth(), isTrue);
    });

    test('register sends lowercase email and returns UserProfile on 201', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/register');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'user@example.com');
        expect(body['password'], 'secure-pass-1234');
        return http.Response(
          jsonEncode({
            'id': 'uuid-123',
            'email': 'user@example.com',
            'is_active': true,
            'created_at': '2026-09-10T12:00:00Z',
          }),
          201,
        );
      });

      final client = AuthApiClient(
        baseUrl: 'https://example.com/api/v1',
        tokenStorage: tokenStorage,
        httpClient: mockClient,
      );

      final profile = await client.register(
        email: '  USER@EXAMPLE.COM ',
        password: 'secure-pass-1234',
      );

      expect(profile.id, 'uuid-123');
      expect(profile.email, 'user@example.com');
      expect(profile.isActive, isTrue);
    });

    test('register throws AuthApiException on 409 conflict', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': {
              'code': 'registration_conflict',
              'message': 'Ya existe una cuenta con este correo.',
            }
          }),
          409,
        );
      });

      final client = AuthApiClient(
        baseUrl: 'https://example.com/api/v1',
        tokenStorage: tokenStorage,
        httpClient: mockClient,
      );

      expect(
        () => client.register(email: 'user@example.com', password: 'password12345'),
        throwsA(isA<AuthApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );
    });

    test('login saves access in memory and refresh in storage', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/login');
        return http.Response(
          jsonEncode({
            'access_token': 'jwt.access.token',
            'refresh_token': 'opaque.refresh.token',
            'token_type': 'bearer',
            'expires_in': 900,
            'session_id': 'sess-123',
          }),
          200,
        );
      });

      final client = AuthApiClient(
        baseUrl: 'https://example.com/api/v1',
        tokenStorage: tokenStorage,
        httpClient: mockClient,
      );

      final tokens = await client.login(
        email: 'user@example.com',
        password: 'secure-pass-1234',
      );

      expect(tokens.accessToken, 'jwt.access.token');
      expect(tokens.refreshToken, 'opaque.refresh.token');
      expect(tokenStorage.accessToken, 'jwt.access.token');
      expect(await tokenStorage.readRefreshToken(), 'opaque.refresh.token');
    });

    test('refreshTokens executes a single concurrent HTTP request', () async {
      var refreshCalls = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/refresh') {
          refreshCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response(
            jsonEncode({
              'access_token': 'new.jwt.access',
              'refresh_token': 'new.opaque.refresh',
              'token_type': 'bearer',
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      await tokenStorage.saveRefreshToken('old.refresh.token');
      final client = AuthApiClient(
        baseUrl: 'https://example.com/api/v1',
        tokenStorage: tokenStorage,
        httpClient: mockClient,
      );

      // Trigger 3 concurrent refreshes
      final results = await Future.wait([
        client.refreshTokens(),
        client.refreshTokens(),
        client.refreshTokens(),
      ]);

      expect(refreshCalls, 1);
      for (final result in results) {
        expect(result?.accessToken, 'new.jwt.access');
        expect(result?.refreshToken, 'new.opaque.refresh');
      }
      expect(tokenStorage.accessToken, 'new.jwt.access');
      expect(await tokenStorage.readRefreshToken(), 'new.opaque.refresh');
    });

    test('refreshTokens clears storage on 401 failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': {
              'code': 'invalid_refresh_token',
              'message': 'Sesión caducada.',
            }
          }),
          401,
        );
      });

      await tokenStorage.saveRefreshToken('invalid.refresh.token');
      tokenStorage.accessToken = 'expired.access';

      final client = AuthApiClient(
        baseUrl: 'https://example.com/api/v1',
        tokenStorage: tokenStorage,
        httpClient: mockClient,
      );

      final result = await client.refreshTokens();
      expect(result, isNull);
      expect(tokenStorage.accessToken, isNull);
      expect(await tokenStorage.readRefreshToken(), isNull);
    });

    test('logout revokes session on server and clears tokens', () async {
      var logoutCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/logout') {
          logoutCalled = true;
          expect(request.headers['Authorization'], 'Bearer jwt.token');
          return http.Response('', 204);
        }
        return http.Response('Not found', 404);
      });

      tokenStorage.accessToken = 'jwt.token';
      await tokenStorage.saveRefreshToken('refresh.token');

      final client = AuthApiClient(
        baseUrl: 'https://example.com/api/v1',
        tokenStorage: tokenStorage,
        httpClient: mockClient,
      );

      await client.logout();
      expect(logoutCalled, isTrue);
      expect(tokenStorage.accessToken, isNull);
      expect(await tokenStorage.readRefreshToken(), isNull);
    });

    test('getSessions returns session list', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/sessions');
        return http.Response(
          jsonEncode([
            {
              'id': 'sess-1',
              'created_at': '2026-09-01T10:00:00Z',
              'expires_at': '2026-10-01T10:00:00Z',
              'last_used_at': '2026-09-10T08:00:00Z',
              'is_current': true,
            },
            {
              'id': 'sess-2',
              'created_at': '2026-08-15T10:00:00Z',
              'expires_at': '2026-09-15T10:00:00Z',
              'is_current': false,
            },
          ]),
          200,
        );
      });

      tokenStorage.accessToken = 'jwt.token';
      final client = AuthApiClient(
        baseUrl: 'https://example.com/api/v1',
        tokenStorage: tokenStorage,
        httpClient: mockClient,
      );

      final sessions = await client.getSessions();
      expect(sessions, hasLength(2));
      expect(sessions.first.id, 'sess-1');
      expect(sessions.first.isCurrent, isTrue);
      expect(sessions.last.id, 'sess-2');
      expect(sessions.last.isCurrent, isFalse);
    });

    test('getScanCapabilities returns providers and availability', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/scans/capabilities');
        return http.Response(
          jsonEncode({
            'providers': [
              {
                'provider_id': 'sherlock',
                'name': 'Sherlock',
                'capabilities': ['username'],
                'available': false,
              },
              {
                'provider_id': 'holehe',
                'name': 'Holehe',
                'capabilities': ['email'],
                'available': false,
              }
            ]
          }),
          200,
        );
      });

      tokenStorage.accessToken = 'jwt.token';
      final client = AuthApiClient(
        baseUrl: 'https://example.com/api/v1',
        tokenStorage: tokenStorage,
        httpClient: mockClient,
      );

      final capabilities = await client.getScanCapabilities();
      expect(capabilities, hasLength(2));
      expect(capabilities[0].providerId, 'sherlock');
      expect(capabilities[0].available, isFalse);
      expect(capabilities[1].providerId, 'holehe');
      expect(capabilities[1].available, isFalse);
    });

    test('getRegistrationOptions requests options and returns challenge', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/passkey/registration/options');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['label'], 'Bóveda Test');
        return http.Response(
          jsonEncode({
            'challenge_token': 'chal-token-123',
            'public_key': {'challenge': 'chal-bytes', 'rp': {'id': 'example.com'}},
          }),
          200,
        );
      });

      final client = AuthApiClient(
        baseUrl: 'https://example.com/api/v1',
        tokenStorage: tokenStorage,
        httpClient: mockClient,
      );

      final res = await client.getRegistrationOptions(label: 'Bóveda Test');
      expect(res['challenge_token'], 'chal-token-123');
      expect(res['public_key']['challenge'], 'chal-bytes');
    });

    test('verifyRegistration sends credential and stores tokens', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/passkey/registration/verify');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['challenge_token'], 'chal-token-123');
        expect(body['credential']['id'], 'cred-123');
        return http.Response(
          jsonEncode({
            'access_token': 'new-jwt',
            'refresh_token': 'new-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {'id': 'usr-1', 'label': 'Mi Bóveda'},
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = AuthApiClient(
        baseUrl: 'https://example.com/api/v1',
        tokenStorage: tokenStorage,
        httpClient: mockClient,
      );

      final tokens = await client.verifyRegistration(
        challengeToken: 'chal-token-123',
        credential: {'id': 'cred-123'},
      );

      expect(tokens.accessToken, 'new-jwt');
      expect(tokenStorage.accessToken, 'new-jwt');
      expect(await tokenStorage.readRefreshToken(), 'new-refresh');
    });

    test('getAuthenticationOptions requests options for login', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/passkey/authentication/options');
        return http.Response(
          jsonEncode({
            'challenge_token': 'auth-token-999',
            'public_key': {'challenge': 'auth-challenge'},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = AuthApiClient(
        baseUrl: 'https://example.com/api/v1',
        tokenStorage: tokenStorage,
        httpClient: mockClient,
      );

      final res = await client.getAuthenticationOptions();
      expect(res['challenge_token'], 'auth-token-999');
    });

    test('verifyAuthentication validates credential and stores tokens', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/passkey/authentication/verify');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['challenge_token'], 'auth-token-999');
        return http.Response(
          jsonEncode({
            'access_token': 'auth-jwt',
            'refresh_token': 'auth-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {'id': 'usr-1', 'label': 'Mi Bóveda'},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = AuthApiClient(
        baseUrl: 'https://example.com/api/v1',
        tokenStorage: tokenStorage,
        httpClient: mockClient,
      );

      final tokens = await client.verifyAuthentication(
        challengeToken: 'auth-token-999',
        credential: {'id': 'cred-auth'},
      );

      expect(tokens.accessToken, 'auth-jwt');
      expect(tokenStorage.accessToken, 'auth-jwt');
      expect(await tokenStorage.readRefreshToken(), 'auth-refresh');
    });
  });
}
