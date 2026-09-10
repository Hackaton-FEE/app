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
    final labelVal = (json['label'] as String?)?.trim();
    final emailVal = (json['email'] as String?)?.trim();
    final effectiveLabel = labelVal?.isNotEmpty == true
        ? labelVal!
        : (emailVal?.isNotEmpty == true ? emailVal! : 'Mi Bóveda FEE');

    final createdAtStr = json['created_at'] as String?;
    final parsedCreatedAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
        : DateTime.now();

    return UserProfile(
      id: json['id'] as String? ?? '',
      label: effectiveLabel,
      email: emailVal ?? effectiveLabel,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: parsedCreatedAt,
      credentialsCount: (json['credentials_count'] as num?)?.toInt() ?? 1,
    );
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
  LocalAccount toLocalAccount({String? displayName}) {
    final effectiveLabel = (label.isNotEmpty && label != 'Mi Bóveda FEE')
        ? label
        : (email.isNotEmpty ? _derivedName(email) : label);
    final name = displayName?.trim().isNotEmpty == true
        ? displayName!
        : (effectiveLabel.isNotEmpty ? effectiveLabel : 'Usuario');
    return LocalAccount(
      id: id,
      name: name,
      email: email.contains('@') ? email : name,
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
