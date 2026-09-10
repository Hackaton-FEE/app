import '../support/in_memory_token_storage.dart';

import 'package:fee_app/features/auth/data/auth_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const live = bool.fromEnvironment('FEE_LIVE_BACKEND_TEST');
  test('Smoke test against live backend server (FastAPI v0.2.0)', () async {
    final tokenStorage = InMemoryTokenStorage();
    final client = AuthApiClient(
      baseUrl: 'https://backosisnt.ici-labs.com/api/v1',
      tokenStorage: tokenStorage,
    );

    // 1. Check health
    final isHealthy = await client.checkHealth();
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
  }, skip: !live);
}
