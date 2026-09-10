import '../../../shared/domain/profile_date.dart';
import '../../accounts/domain/local_account.dart';

/// Perfil de usuario devuelto por `/api/v1/auth/me` (FastAPI v0.2.0).
class UserProfile {
  const UserProfile({
    required this.id,
    this.label = 'Mi Bóveda FEE',
    this.email = '',
    this.isActive = true,
    required this.createdAt,
    this.credentialsCount = 1,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String;
      final label = json['label'] as String;
      final count = json['credentials_count'] as int;
      if (id.trim().isEmpty || count < 0) throw const FormatException();
      final active = json.containsKey('is_active')
          ? json['is_active'] as bool
          : true;
      return UserProfile(
        id: id,
        label: label,
        email: json['email'] == null ? '' : json['email'] as String,
        isActive: active,
        createdAt: parseProfileDate(json['created_at']),
        credentialsCount: count,
      );
    } catch (_) {
      throw const FormatException('El perfil del servidor no es válido.');
    }
  }

  final String id;
  final String label;
  final String email;
  final bool isActive;
  final DateTime createdAt;
  final int credentialsCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'email': email,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'credentials_count': credentialsCount,
  };

  /// Convierte el perfil del backend a [LocalAccount] para ser usado en el resto de la app.
  LocalAccount toLocalAccount({String? displayName}) => LocalAccount(
    id: id,
    name: displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : (label.trim().isNotEmpty ? label : 'Usuario'),
    email: email,
    isActive: isActive,
    createdAt: createdAt,
  );
}
