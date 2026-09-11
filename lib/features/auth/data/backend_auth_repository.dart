import '../domain/user_profile.dart';
import 'auth_api_client.dart';
import 'passkey_authenticator.dart';
import 'token_storage.dart';

abstract interface class AuthRepository {
  Future<bool> checkHealth();
  Future<UserProfile> registerWithPasskey({
    String label = 'Mi Bóveda FEE',
    PasskeyAuthenticator? authenticator,
  });
  Future<UserProfile> loginWithPasskey({PasskeyAuthenticator? authenticator});
  Future<UserProfile?> restoreSession();
  Future<void> logout();
  Future<UserProfile> getProfile();
}

class BackendAuthRepository implements AuthRepository {
  factory BackendAuthRepository({
    AuthApiClient? apiClient,
    TokenStorage? tokenStorage,
    PasskeyAuthenticator? authenticator,
  }) {
    final effectiveStorage =
        tokenStorage ?? apiClient?.tokenStorage ?? SecureTokenStorage();
    final effectiveClient =
        apiClient ?? AuthApiClient(tokenStorage: effectiveStorage);
    return BackendAuthRepository._(
      storage: effectiveStorage,
      client: effectiveClient,
      authenticator: authenticator ?? NativePasskeyAuthenticator(),
    );
  }

  BackendAuthRepository._({
    required this._storage,
    required this._client,
    required this._authenticator,
  });

  final TokenStorage _storage;
  final AuthApiClient _client;
  final PasskeyAuthenticator _authenticator;

  AuthApiClient get apiClient => _client;
  TokenStorage get tokenStorage => _storage;
  PasskeyAuthenticator get authenticator => _authenticator;

  @override
  Future<bool> checkHealth() => _client.checkHealth();

  @override
  Future<UserProfile> registerWithPasskey({
    String label = 'Mi Bóveda FEE',
    PasskeyAuthenticator? authenticator,
  }) async {
    final effectiveAuth = authenticator ?? _authenticator;
    final options = await _client.getRegistrationOptions(label: label);
    final challengeToken = options['challenge_token'] as String;
    final publicKey = options['public_key'] as Map<String, dynamic>;

    final credential = await effectiveAuth.createCredential(publicKey);
    await _client.verifyRegistration(
      challengeToken: challengeToken,
      credential: credential,
    );
    return _client.getMe();
  }

  @override
  Future<UserProfile> loginWithPasskey({
    PasskeyAuthenticator? authenticator,
  }) async {
    final effectiveAuth = authenticator ?? _authenticator;
    final options = await _client.getAuthenticationOptions();
    final challengeToken = options['challenge_token'] as String;
    final publicKey = options['public_key'] as Map<String, dynamic>;

    final credential = await effectiveAuth.getCredential(publicKey);
    await _client.verifyAuthentication(
      challengeToken: challengeToken,
      credential: credential,
    );
    return _client.getMe();
  }

  @override
  Future<UserProfile?> restoreSession() async {
    final tokens = await _client.refreshTokens();
    if (tokens == null) return null;
    return _client.getMe();
  }

  @override
  Future<void> logout() => _client.logout();

  @override
  Future<UserProfile> getProfile() => _client.getMe();

  /// Renueva una sesión existente. El acceso nativo requiere una acción explícita.
  Future<String> ensureAccessToken({bool forceRefresh = false}) async {
    final current = _storage.accessToken;
    if (!forceRefresh && current != null && current.isNotEmpty) return current;
    _storage.accessToken = null;
    final restored = await restoreSession();
    final refreshed = _storage.accessToken;
    if (restored != null && refreshed != null && refreshed.isNotEmpty) {
      return refreshed;
    }
    throw const AuthApiException(
      message: 'Tu sesión venció. Inicia sesión con tu llave de acceso.',
      code: 'auth_required',
    );
  }
}
