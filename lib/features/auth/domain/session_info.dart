/// Información de una sesión activa devuelta por `GET /api/v1/auth/sessions`.
class SessionInfo {
  const SessionInfo({
    required this.id,
    required this.createdAt,
    required this.expiresAt,
    this.lastUsedAt,
    required this.isCurrent,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'] as String)
          : null,
      isCurrent: json['is_current'] as bool? ?? false,
    );
  }

  final String id;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? lastUsedAt;
  final bool isCurrent;
}
