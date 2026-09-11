import 'dart:async';
import 'dart:convert';

import 'package:fee_app/features/auth/data/auth_api_client.dart';
import 'package:fee_app/features/auth/data/backend_auth_repository.dart';
import 'package:fee_app/features/auth/data/passkey_authenticator.dart';
import 'package:fee_app/features/auth/data/token_storage.dart';
import 'package:fee_app/features/footprint/data/osint_client.dart';
import 'package:fee_app/features/guard_ai/data/assistant_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/in_memory_token_storage.dart';

class _ForbiddenPasskey extends PasskeyAuthenticator {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Passkey must never be invoked during testing');
}

http.Response _tokens(String name, [int status = 200]) => http.Response(
  jsonEncode({
    'access_token': '$name-access',
    'refresh_token': '$name-refresh',
  }),
  status,
);
http.Response _profile() => http.Response(
  jsonEncode({
    'id': 'testing-account',
    'label': 'Pruebas',
    'credentials_count': 0,
    'created_at': '2026-09-11T12:00:00Z',
  }),
  200,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'restoration and background requests never create a testing account',
    () async {
      final repository = BackendAuthRepository(
        testingAccessEnabled: true,
        apiClient: AuthApiClient(
          tokenStorage: InMemoryTokenStorage(),
          httpClient: MockClient(
            (_) async => throw StateError('No HTTP before Enter'),
          ),
        ),
      );
      expect(await repository.restoreSession(), isNull);
      await expectLater(
        repository.ensureAccessToken(),
        throwsA(isA<AuthApiException>()),
      );
    },
  );

  test('testing logout clears access only and explicit reentry restores same identity', () async {
    final storage = InMemoryTokenStorage();
    final paths = <String>[];
    final repository = BackendAuthRepository(
      testingAccessEnabled: true,
      apiClient: AuthApiClient(
        tokenStorage: storage,
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/testing/session')) {
            return _tokens('guest', 201);
          }
          if (request.url.path.endsWith('/token/refresh')) {
            return _tokens('renewed');
          }
          expect(request.url.path, '/api/v1/auth/me');
          return _profile();
        }),
      ),
    );
    final first = await repository.startTestingSession();
    await repository.logout();
    expect(storage.accessToken, isNull);
    expect(await storage.readRefreshToken(), 'guest-refresh');
    await expectLater(
      repository.ensureAccessToken(),
      throwsA(isA<AuthApiException>()),
    );
    expect(paths, ['/api/v1/auth/testing/session', '/api/v1/auth/me']);
    final second = await repository.startTestingSession();
    expect(second.id, first.id);
    expect(paths, [
      '/api/v1/auth/testing/session',
      '/api/v1/auth/me',
      '/api/v1/auth/token/refresh',
      '/api/v1/auth/me',
    ]);
  });

  test(
    'concurrent explicit entry creates one account without invoking Passkey',
    () async {
      final storage = InMemoryTokenStorage();
      final paths = <String>[];
      final repository = BackendAuthRepository(
        testingAccessEnabled: true,
        authenticator: _ForbiddenPasskey(),
        apiClient: AuthApiClient(
          tokenStorage: storage,
          httpClient: MockClient((request) async {
            paths.add(request.url.path);
            if (request.url.path.endsWith('/testing/session')) {
              expect(request.method, 'POST');
              expect(jsonDecode(request.body), isEmpty);
              expect(request.headers.containsKey('Authorization'), isFalse);
              return _tokens('guest', 201);
            }
            expect(request.url.path, '/api/v1/auth/me');
            expect(request.headers['Authorization'], 'Bearer guest-access');
            return _profile();
          }),
        ),
      );
      final profiles = await Future.wait(
        List.generate(5, (_) => repository.startTestingSession()),
      );
      expect(profiles.map((p) => p.id).toSet(), {'testing-account'});
      expect(profiles.first.toLocalAccount().email, isEmpty);
      expect(paths, ['/api/v1/auth/testing/session', '/api/v1/auth/me']);
      expect(await storage.readRefreshToken(), 'guest-refresh');
      await expectLater(
        repository.loginWithPasskey(),
        throwsA(isA<AuthApiException>()),
      );
      await expectLater(
        repository.registerWithPasskey(),
        throwsA(isA<AuthApiException>()),
      );
      expect(paths.length, 2);
    },
  );

  test(
    'reopen renews persisted testing identity without creating another account',
    () async {
      final storage = InMemoryTokenStorage(
        initialRefreshToken: 'saved-refresh',
      );
      final paths = <String>[];
      final repository = BackendAuthRepository(
        testingAccessEnabled: true,
        apiClient: AuthApiClient(
          tokenStorage: storage,
          httpClient: MockClient((request) async {
            paths.add(request.url.path);
            if (request.url.path.endsWith('/token/refresh')) {
              expect(jsonDecode(request.body), {
                'refresh_token': 'saved-refresh',
              });
              return _tokens('renewed');
            }
            return _profile();
          }),
        ),
      );
      expect((await repository.startTestingSession()).id, 'testing-account');
      expect(paths, ['/api/v1/auth/token/refresh', '/api/v1/auth/me']);
    },
  );

  test('disabled testing and network failures remain retryable without Passkey fallback', () async {
    var attempt = 0;
    final repository = BackendAuthRepository(
      testingAccessEnabled: true,
      authenticator: _ForbiddenPasskey(),
      apiClient: AuthApiClient(
        tokenStorage: InMemoryTokenStorage(),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/me')) return _profile();
          expect(request.url.path, '/api/v1/auth/testing/session');
          attempt++;
          if (attempt == 1) {
            return http.Response(
              '{"type":"https://example.invalid/testing-access-disabled"}',
              403,
            );
          }
          if (attempt == 2) throw http.ClientException('offline');
          return _tokens('guest', 201);
        }),
      ),
    );
    await expectLater(
      repository.startTestingSession(),
      throwsA(
        isA<AuthApiException>().having(
          (e) => e.code,
          'code',
          'testing-access-disabled',
        ),
      ),
    );
    await expectLater(
      repository.startTestingSession(),
      throwsA(isA<http.ClientException>()),
    );
    expect((await repository.startTestingSession()).id, 'testing-account');
    expect(attempt, 3);
  });

  test(
    'invalid refresh never changes account during scan or retries',
    () async {
      var creates = 0;
      final repository = BackendAuthRepository(
        testingAccessEnabled: true,
        apiClient: AuthApiClient(
          tokenStorage: InMemoryTokenStorage(),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/testing/session')) {
              creates++;
              return _tokens('guest', 201);
            }
            if (request.url.path.endsWith('/me')) return _profile();
            expect(request.url.path, '/api/v1/auth/token/refresh');
            return http.Response('{}', 401);
          }),
        ),
      );
      await repository.startTestingSession();
      for (var i = 0; i < 3; i++) {
        await expectLater(
          repository.ensureAccessToken(forceRefresh: true),
          throwsA(
            isA<AuthApiException>().having(
              (e) => e.code,
              'code',
              'auth_required',
            ),
          ),
        );
      }
      await expectLater(
        repository.startTestingSession(),
        throwsA(isA<AuthApiException>()),
      );
      expect(creates, 1);
    },
  );

  test('OSINT and LLM share Bearer session and one concurrent refresh on 401', () async {
    final refreshStarted = Completer<void>();
    final allowRefresh = Completer<void>();
    var renewals = 0;
    final storage = InMemoryTokenStorage();
    final repository = BackendAuthRepository(
      testingAccessEnabled: true,
      apiClient: AuthApiClient(
        tokenStorage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/testing/session')) {
            return _tokens('guest', 201);
          }
          if (request.url.path.endsWith('/me')) return _profile();
          expect(request.url.path, '/api/v1/auth/token/refresh');
          renewals++;
          refreshStarted.complete();
          await allowRefresh.future;
          return _tokens('renewed');
        }),
      ),
    );
    await repository.startTestingSession();
    final originalRequests = <String>{};
    final bothRejected = Completer<void>();
    final client = MockClient((request) async {
      final token = request.headers['Authorization'];
      if (token == 'Bearer guest-access') {
        originalRequests.add(request.url.path);
        if (originalRequests.length == 2) bothRejected.complete();
        return http.Response('{}', 401);
      }
      expect(token, 'Bearer renewed-access');
      if (request.url.path.endsWith('/osint/scans')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['identifier'], '+525512345678');
        expect(body['associated_usernames'], ['actual_client']);
        expect(body['associated_email'], 'client@example.invalid');
        return http.Response('{"scan_id":"scan-1"}', 202);
      }
      expect(request.url.path, '/api/v1/assistant/chat');
      return http.Response(
        'event: token\ndata: {"content":"Listo"}\n\nevent: done\ndata: {}\n\n',
        200,
      );
    });
    final osint = OsintClient(
      httpClient: client,
      tokenProvider: () => storage.accessToken,
      asyncTokenProvider: repository.ensureAccessToken,
    );
    final assistant = AssistantClient(
      httpClient: client,
      tokenProvider: () => storage.accessToken,
      asyncTokenProvider: repository.ensureAccessToken,
    );
    final scan = osint.startScan(
      mainIdentifier: '+525512345678',
      associatedEmail: 'client@example.invalid',
      associatedUsernames: ['actual_client'],
    );
    final chat = assistant.chat([
      {'role': 'user', 'content': 'Ayuda'},
    ]);
    await bothRejected.future;
    await refreshStarted.future;
    allowRefresh.complete();
    expect(await scan, 'scan-1');
    expect(await chat, 'Listo');
    expect(renewals, 1);
  });

  test(
    'testing token namespace preserves Passkey session and native reference',
    () async {
      const passkeyIdKey = 'fee.auth.v2.native_passkey_credential_id';
      FlutterSecureStorage.setMockInitialValues({
        SecureTokenStorage.passkeyRefreshKey: 'passkey-refresh',
        passkeyIdKey: 'native-credential-id',
      });
      final repository = BackendAuthRepository(testingAccessEnabled: true);
      expect(
        (repository.tokenStorage as SecureTokenStorage).refreshKey,
        SecureTokenStorage.testingRefreshKey,
      );
      await repository.tokenStorage.saveRefreshToken('guest-refresh');
      final reopened = BackendAuthRepository(testingAccessEnabled: true);
      expect(await reopened.tokenStorage.readRefreshToken(), 'guest-refresh');
      await reopened.tokenStorage.clearAll();
      expect(await SecureTokenStorage().readRefreshToken(), 'passkey-refresh');
      expect(
        await const FlutterSecureStorage().read(key: passkeyIdKey),
        'native-credential-id',
      );
    },
  );

  for (final reenter in [false, true]) {
    test('logout rejects pending refresh retry; reenter=$reenter', () async {
      final refreshStarted = Completer<void>();
      final releaseRefresh = Completer<void>();
      var refreshCalls = 0;
      final repository = BackendAuthRepository(
        testingAccessEnabled: true,
        apiClient: AuthApiClient(
          tokenStorage: InMemoryTokenStorage(),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/testing/session')) {
              return _tokens('guest', 201);
            }
            if (request.url.path.endsWith('/me')) return _profile();
            expect(request.url.path, '/api/v1/auth/token/refresh');
            refreshCalls++;
            refreshStarted.complete();
            await releaseRefresh.future;
            return _tokens('rotated');
          }),
        ),
      );
      await repository.startTestingSession();
      final stale = repository.ensureAccessToken(forceRefresh: true);
      final rejected = expectLater(stale, throwsA(isA<AuthApiException>()));
      await refreshStarted.future;
      await repository.logout();
      final reentry = reenter ? repository.startTestingSession() : null;
      releaseRefresh.complete();
      await rejected;
      if (reentry != null) {
        expect((await reentry).id, 'testing-account');
        expect(repository.accessToken, 'rotated-access');
        expect(await repository.ensureAccessToken(), 'rotated-access');
      } else {
        expect(repository.accessToken, isNull);
        await expectLater(
          repository.ensureAccessToken(),
          throwsA(isA<AuthApiException>()),
        );
      }
      expect(refreshCalls, 1);
    });
  }
}
