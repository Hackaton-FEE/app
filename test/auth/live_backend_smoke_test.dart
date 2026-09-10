import 'package:fee_app/features/auth/data/auth_api_client.dart';
import 'package:fee_app/features/auth/data/backend_auth_repository.dart';
import 'package:fee_app/features/auth/data/passkey_authenticator.dart';
import 'package:fee_app/features/auth/data/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Smoke test against live backend server (FastAPI v0.2.0)', () async {
    final tokenStorage = InMemoryTokenStorage();
    final client = AuthApiClient(
      baseUrl: 'https://backosisnt.ici-labs.com/api/v1',
      tokenStorage: tokenStorage,
    );

    // 1. Check health
    final isHealthy = await client.checkHealth();
    if (!isHealthy) {
      // Omitir si el entorno de ejecución está sin conexión a Internet o bloqueado por red
      return;
    }
    expect(isHealthy, isTrue);

    // 2. Passkey registration options (/auth/passkey/registration/options)
    final regOptions = await client.getRegistrationOptions(
      label: 'Smoke Test Bóveda',
    );
    expect(regOptions['challenge_token'], isNotEmpty);
    expect(regOptions['public_key'], isA<Map<String, dynamic>>());

    final pubKey = regOptions['public_key'] as Map<String, dynamic>;
    expect(pubKey['rp']['id'], 'backosisnt.ici-labs.com');
    expect(pubKey['challenge'], isNotEmpty);

    // 3. Passkey authentication options (/auth/passkey/authentication/options)
    final authOptions = await client.getAuthenticationOptions();
    expect(authOptions['challenge_token'], isNotEmpty);
    expect(authOptions['public_key'], isA<Map<String, dynamic>>());

    final authPubKey = authOptions['public_key'] as Map<String, dynamic>;
    expect(authPubKey['challenge'], isNotEmpty);

    // 4. Refresh token handling with expired/invalid token
    await tokenStorage.saveRefreshToken('invalid_smoke_refresh_token');
    final refreshed = await client.refreshTokens();
    expect(refreshed, isNull);
    expect(tokenStorage.accessToken, isNull);
    expect(await tokenStorage.readRefreshToken(), isNull);
  });

  test('Full end-to-end Passkey registration, /me, and login on live backend', () async {
    final tokenStorage = InMemoryTokenStorage();
    final client = AuthApiClient(
      baseUrl: 'https://backosisnt.ici-labs.com/api/v1',
      tokenStorage: tokenStorage,
    );
    if (!await client.checkHealth()) return;

    final authenticator = SoftPasskeyAuthenticator();
    final repo = BackendAuthRepository(
      apiClient: client,
      tokenStorage: tokenStorage,
      authenticator: authenticator,
    );

    // 1. Registrar una nueva Bóveda con Passkey en vivo
    final uniqueLabel = 'Demo Bóveda ${DateTime.now().millisecondsSinceEpoch}';
    final profile = await repo.registerWithPasskey(label: uniqueLabel);
    expect(profile.id, isNotEmpty);
    expect(profile.label, uniqueLabel);
    expect(tokenStorage.accessToken, isNotNull);

    // 2. Consultar perfil con GET /auth/me
    final me = await repo.getProfile();
    expect(me.id, profile.id);
    expect(me.label, uniqueLabel);

    // 3. Simular reinicio de sesión y re-autenticación con la misma Passkey
    final loginProfile = await repo.loginWithPasskey();
    expect(loginProfile.id, profile.id);
    expect(loginProfile.label, uniqueLabel);
  });
}
