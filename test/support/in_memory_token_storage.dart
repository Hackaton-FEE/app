import 'package:fee_app/features/auth/data/token_storage.dart';

class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage({
    String? initialRefreshToken,
    String? initialAccessToken,
  }) : _refreshToken = initialRefreshToken,
       _accessToken = initialAccessToken;

  String? _refreshToken;
  String? _accessToken;

  @override
  String? get accessToken => _accessToken;

  @override
  set accessToken(String? token) {
    _accessToken = token;
  }

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<void> saveRefreshToken(String token) async {
    _refreshToken = token;
  }

  @override
  Future<void> clearRefreshToken() async {
    _refreshToken = null;
  }

  @override
  Future<void> clearAll() async {
    _refreshToken = null;
    _accessToken = null;
  }
}
