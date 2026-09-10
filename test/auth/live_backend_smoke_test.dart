import 'package:fee_app/features/auth/data/auth_api_client.dart';
import 'package:fee_app/features/auth/data/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Smoke test against live backend server', () async {
    final tokenStorage = InMemoryTokenStorage();
    final client = AuthApiClient(
      baseUrl: 'https://backosisnt.ici-labs.com/api/v1',
      tokenStorage: tokenStorage,
    );

    // 1. Check health
    final isHealthy = await client.checkHealth();
    if (!isHealthy) {
      // Omitir si el entorno de ejecución está sin conexión a Internet
      return;
    }
    expect(isHealthy, isTrue);

    // 2. Register test account
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final testEmail = 'smoke_test_$timestamp@gmail.com';
    const testPassword = 'Password123456789!';

    final profile = await client.register(
      email: testEmail,
      password: testPassword,
    );
    expect(profile.email, testEmail);
    expect(profile.isActive, isTrue);
    expect(profile.id, isNotEmpty);

    // 3. Login with test account
    final tokens = await client.login(
      email: testEmail,
      password: testPassword,
    );
    expect(tokens.accessToken, isNotEmpty);
    expect(tokens.refreshToken, isNotEmpty);

    // 4. Get profile (/auth/me)
    final me = await client.getMe();
    expect(me.id, profile.id);
    expect(me.email, testEmail);

    // 5. Scan capabilities (/scans/capabilities)
    final caps = await client.getScanCapabilities();
    expect(caps, isNotEmpty);
    for (final cap in caps) {
      expect(cap.available, isFalse);
    }

    // 6. Get sessions (/auth/sessions)
    final sessions = await client.getSessions();
    expect(sessions, isNotEmpty);
    expect(sessions.any((s) => s.isCurrent), isTrue);

    // 7. Refresh token (/auth/refresh)
    final refreshed = await client.refreshTokens();
    expect(refreshed, isNotNull);
    expect(refreshed!.accessToken, isNotEmpty);
    expect(refreshed.refreshToken, isNotEmpty);

    // 8. Logout (/auth/logout)
    await client.logout();
    expect(tokenStorage.accessToken, isNull);
    expect(await tokenStorage.readRefreshToken(), isNull);
  });
}
