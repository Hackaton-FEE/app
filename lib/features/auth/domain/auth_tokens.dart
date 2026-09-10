/// Tokens y metadatos de sesión devueltos por el backend en login y refresh.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
    this.expiresIn,
    this.refreshExpiresIn,
    this.sessionId,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int?,
      refreshExpiresIn: json['refresh_expires_in'] as int?,
      sessionId: json['session_id'] as String?,
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int? expiresIn;
  final int? refreshExpiresIn;
  final String? sessionId;

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'token_type': tokenType,
    if (expiresIn != null) 'expires_in': expiresIn,
    if (refreshExpiresIn != null) 'refresh_expires_in': refreshExpiresIn,
    if (sessionId != null) 'session_id': sessionId,
  };
}
