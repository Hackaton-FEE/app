import '../../accounts/domain/local_account.dart';

/// Perfil de usuario devuelto por `/api/v1/auth/me` o `/api/v1/auth/register`.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.isActive,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String email;
  final bool isActive;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
  };

  /// Convierte el perfil del backend a [LocalAccount] para ser usado en el resto de la app.
  LocalAccount toLocalAccount({String? displayName}) {
    final name = displayName?.trim().isNotEmpty == true
        ? displayName!
        : _derivedName(email);
    return LocalAccount(
      id: id,
      name: name,
      email: email,
      isDemo: false,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  static String _derivedName(String email) {
    final parts = email.split('@');
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      final user = parts.first;
      return user[0].toUpperCase() + user.substring(1);
    }
    return 'Usuario';
  }
}
