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
    bool testingAccessEnabled = false,
  }) {
    final effectiveStorage =
        tokenStorage ??
        apiClient?.tokenStorage ??
        SecureTokenStorage(
          refreshKey: testingAccessEnabled
              ? SecureTokenStorage.testingRefreshKey
              : SecureTokenStorage.passkeyRefreshKey,
        );
    final effectiveClient =
        apiClient ?? AuthApiClient(tokenStorage: effectiveStorage);
    return BackendAuthRepository._(
      storage: effectiveStorage,
      client: effectiveClient,
      authenticator: authenticator,
      testingAccessEnabled: testingAccessEnabled,
    );
  }

  BackendAuthRepository._({
    required this._storage,
    required this._client,
    required this._authenticator,
    required this.testingAccessEnabled,
  });

  final TokenStorage _storage;
  final AuthApiClient _client;
  PasskeyAuthenticator? _authenticator;
  final bool testingAccessEnabled;
  Future<UserProfile?>? _restoreInProgress;
  Future<UserProfile>? _testingSignIn;
  bool _testingSessionEstablished = false;
  int _sessionGeneration = 0;

  AuthApiClient get apiClient => _client;
  TokenStorage get tokenStorage => _storage;
  String? get accessToken => testingAccessEnabled && !_testingSessionEstablished
      ? null
      : _storage.accessToken;
  PasskeyAuthenticator get authenticator =>
      _authenticator ??= NativePasskeyAuthenticator();

  @override
  Future<bool> checkHealth() => _client.checkHealth();

  @override
  Future<UserProfile> registerWithPasskey({
    String label = 'Mi Bóveda FEE',
    PasskeyAuthenticator? authenticator,
  }) async {
    _requirePasskeyMode();
    final effectiveAuth = authenticator ?? this.authenticator;
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
    _requirePasskeyMode();
    final effectiveAuth = authenticator ?? this.authenticator;
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
  Future<UserProfile?> restoreSession() => _restoreInProgress ??=
      _restoreSession().whenComplete(() => _restoreInProgress = null);

  Future<UserProfile?> _restoreSession() async {
    if (_storage.accessToken == null || _storage.accessToken!.isEmpty) {
      final tokens = await _client.refreshTokens();
      if (tokens == null) return null;
    }
    final profile = await _client.getMe();
    _testingSessionEstablished = testingAccessEnabled;
    return profile;
  }

  /// Solo el botón Entrar puede preparar una cuenta de pruebas nueva.
  Future<UserProfile> startTestingSession() => _testingSignIn ??=
      _startTestingSession().whenComplete(() => _testingSignIn = null);

  Future<UserProfile> _startTestingSession() async {
    if (!testingAccessEnabled) throw _sessionExpired;
    final existing = await restoreSession();
    if (existing != null) return existing;
    if (_testingSessionEstablished) throw _sessionExpired;
    await _client.createTestingSession();
    final profile = await _client.getMe();
    _testingSessionEstablished = true;
    return profile;
  }

  @override
  Future<void> logout() async {
    if (testingAccessEnabled) {
      // Salida local de la interfaz: Entrar recupera la misma cuenta e historial.
      _sessionGeneration++;
      _storage.accessToken = null;
    } else {
      await _client.logout();
    }
    _testingSessionEstablished = false;
  }

  @override
  Future<UserProfile> getProfile() => _client.getMe();

  /// Renueva la misma cuenta; una petición nunca crea una identidad de reemplazo.
  Future<String> ensureAccessToken({bool forceRefresh = false}) async {
    final generation = _sessionGeneration;
    if (testingAccessEnabled && !_testingSessionEstablished) {
      throw _sessionExpired;
    }
    final current = _storage.accessToken;
    if (!forceRefresh && current != null && current.isNotEmpty) return current;
    _storage.accessToken = null;
    final refreshed = await _client.refreshTokens();
    if (testingAccessEnabled &&
        (generation != _sessionGeneration || !_testingSessionEstablished)) {
      throw _sessionExpired;
    }
    if (refreshed != null && refreshed.accessToken.isNotEmpty) {
      return refreshed.accessToken;
    }
    throw _sessionExpired;
  }

  AuthApiException get _sessionExpired => AuthApiException(
    message: testingAccessEnabled
        ? 'La sesión de pruebas venció. Cierra sesión y pulsa Entrar para continuar.'
        : 'Tu sesión venció. Inicia sesión con tu llave de acceso.',
    code: 'auth_required',
  );

  void _requirePasskeyMode() {
    if (testingAccessEnabled) {
      throw const AuthApiException(
        message:
            'Las llaves de acceso están deshabilitadas durante las pruebas.',
        code: 'passkey_disabled',
      );
    }
  }
}
