import '../support/in_memory_token_storage.dart';

import 'dart:convert';

import 'package:fee_app/features/auth/data/auth_api_client.dart';
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

    test('refreshTokens executes a single concurrent HTTP request', () async {
      var refreshCalls = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/token/refresh') {
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
            },
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

    test(
      'unsupported catalogs never fabricate data or call absent routes',
      () async {
        var calls = 0;
        final client = AuthApiClient(
          tokenStorage: tokenStorage,
          httpClient: MockClient((request) async {
            calls++;
            return http.Response('{}', 200);
          }),
        );
        await expectLater(
          client.getSessions(),
          throwsA(isA<AuthApiException>()),
        );
        await expectLater(
          client.getScanCapabilities(),
          throwsA(isA<AuthApiException>()),
        );
        await expectLater(
          client.revokeSession('test'),
          throwsA(isA<AuthApiException>()),
        );
        expect(calls, 0);
      },
    );

    test(
      'failed refresh preserves existing credentials and shares the error',
      () async {
        await tokenStorage.saveRefreshToken('existing-refresh');
        tokenStorage.accessToken = 'existing-access';
        var calls = 0;
        final client = AuthApiClient(
          tokenStorage: tokenStorage,
          httpClient: MockClient((request) async {
            calls++;
            return http.Response('{}', 503);
          }),
        );
        final first = client.refreshTokens();
        final second = client.refreshTokens();
        await Future.wait([
          expectLater(first, throwsA(isA<AuthApiException>())),
          expectLater(second, throwsA(isA<AuthApiException>())),
        ]);
        expect(calls, 1);
        expect(await tokenStorage.readRefreshToken(), 'existing-refresh');
        expect(tokenStorage.accessToken, 'existing-access');
      },
    );

    test(
      'getRegistrationOptions requests options and returns challenge',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/passkey/registration/options');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['label'], 'Bóveda Test');
          return http.Response(
            jsonEncode({
              'challenge_token': 'chal-token-123',
              'public_key': {
                'challenge': 'chal-bytes',
                'rp': {'id': 'example.com'},
              },
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
      },
    );

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

    test(
      'verifyAuthentication validates credential and stores tokens',
      () async {
        final mockClient = MockClient((request) async {
          expect(
            request.url.path,
            '/api/v1/auth/passkey/authentication/verify',
          );
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
      },
    );
  });
}
