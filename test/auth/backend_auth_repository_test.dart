import 'dart:convert';

import 'package:fee_app/features/auth/data/auth_api_client.dart';
import 'package:fee_app/features/auth/data/backend_auth_repository.dart';
import 'package:fee_app/features/auth/data/passkey_authenticator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/in_memory_token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses native passkeys by default and shares injected token storage', () {
    final storage = InMemoryTokenStorage();
    final client = AuthApiClient(tokenStorage: storage);
    final repository = BackendAuthRepository(apiClient: client);
    expect(repository.authenticator, isA<NativePasskeyAuthenticator>());
    expect(repository.tokenStorage, same(storage));
  });

  test('expired session never starts implicit login or registration', () async {
    final storage = InMemoryTokenStorage();
    final client = AuthApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        fail('No session: must not create challenges or register');
      }),
    );
    final repository = BackendAuthRepository(apiClient: client);
    await expectLater(
      repository.ensureAccessToken(),
      throwsA(
        isA<AuthApiException>().having((e) => e.code, 'code', 'auth_required'),
      ),
    );
  });

  test('profile failure preserves rotated refresh for a later retry', () async {
    final storage = InMemoryTokenStorage(initialRefreshToken: 'old-refresh');
    final client = AuthApiClient(
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/token/refresh')) {
          return http.Response(
            jsonEncode({
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
            }),
            200,
          );
        }
        expect(request.url.path, '/api/v1/auth/me');
        return http.Response('{}', 503);
      }),
    );
    final repository = BackendAuthRepository(apiClient: client);
    await expectLater(
      repository.restoreSession(),
      throwsA(isA<AuthApiException>()),
    );
    expect(await storage.readRefreshToken(), 'new-refresh');
    expect(storage.accessToken, 'new-access');
  });

  test('refresh transport failure preserves existing credentials', () async {
    final storage = InMemoryTokenStorage(initialRefreshToken: 'old-refresh');
    final client = AuthApiClient(
      tokenStorage: storage,
      httpClient: MockClient(
        (_) async => throw http.ClientException('network down'),
      ),
    );
    final repository = BackendAuthRepository(apiClient: client);
    await expectLater(
      repository.restoreSession(),
      throwsA(isA<http.ClientException>()),
    );
    expect(await storage.readRefreshToken(), 'old-refresh');
  });
}
