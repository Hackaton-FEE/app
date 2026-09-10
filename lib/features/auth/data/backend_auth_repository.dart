import '../domain/scan_capability.dart';
import '../domain/session_info.dart';
import '../domain/user_profile.dart';
import 'auth_api_client.dart';
import 'token_storage.dart';

abstract interface class AuthRepository {
  Future<bool> checkHealth();
  Future<UserProfile> register({
    required String email,
    required String password,
  });
  Future<UserProfile> login({
    required String email,
    required String password,
  });
  Future<UserProfile?> restoreSession();
  Future<void> logout();
  Future<UserProfile> getProfile();
  Future<List<SessionInfo>> getSessions();
  Future<void> revokeSession(String sessionId);
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<List<ScanCapabilityProvider>> getScanCapabilities();
}

class BackendAuthRepository implements AuthRepository {
  BackendAuthRepository({
    AuthApiClient? apiClient,
    TokenStorage? tokenStorage,
  }) : _storage = tokenStorage ?? SecureTokenStorage(),
       _client = apiClient ??
           AuthApiClient(
             tokenStorage: tokenStorage ?? SecureTokenStorage(),
           );

  final TokenStorage _storage;
  final AuthApiClient _client;

  AuthApiClient get apiClient => _client;
  TokenStorage get tokenStorage => _storage;

  @override
  Future<bool> checkHealth() => _client.checkHealth();

  @override
  Future<UserProfile> register({
    required String email,
    required String password,
  }) =>
      _client.register(email: email, password: password);

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    await _client.login(email: email, password: password);
    return _client.getMe();
  }

  @override
  Future<UserProfile?> restoreSession() async {
    try {
      final tokens = await _client.refreshTokens();
      if (tokens == null) return null;
      return await _client.getMe();
    } catch (_) {
      await _storage.clearAll();
      return null;
    }
  }

  @override
  Future<void> logout() => _client.logout();

  @override
  Future<UserProfile> getProfile() => _client.getMe();

  @override
  Future<List<SessionInfo>> getSessions() => _client.getSessions();

  @override
  Future<void> revokeSession(String sessionId) =>
      _client.revokeSession(sessionId);

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _client.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  @override
  Future<List<ScanCapabilityProvider>> getScanCapabilities() =>
      _client.getScanCapabilities();
}
