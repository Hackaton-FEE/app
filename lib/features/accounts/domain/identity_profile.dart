import 'dart:convert';

/// Perfil de identidad personal monitoreada para auditorías de huella OSINT.
class IdentityProfile {
  const IdentityProfile({
    required this.accountId,
    required this.mainIdentifier,
    this.fullName,
    this.associatedUsernames = const [],
    this.associatedEmail,
    this.phone,
    this.consentSelfAudit = true,
    this.hasCompletedOnboarding = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory IdentityProfile.fromJson(Map<String, dynamic> json) {
    final rawUsernames = json['associated_usernames'] as List<dynamic>? ?? const [];
    final usernames = rawUsernames
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return IdentityProfile(
      accountId: json['account_id'] as String? ?? '',
      mainIdentifier: (json['main_identifier'] as String? ?? '').trim(),
      fullName: (json['full_name'] as String?)?.trim(),
      associatedUsernames: List.unmodifiable(usernames),
      associatedEmail: (json['associated_email'] as String?)?.trim(),
      phone: (json['phone'] as String?)?.trim(),
      consentSelfAudit: json['consent_self_audit'] as bool? ?? true,
      hasCompletedOnboarding: json['has_completed_onboarding'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  final String accountId;
  final String mainIdentifier;
  final String? fullName;
  final List<String> associatedUsernames;
  final String? associatedEmail;
  final String? phone;
  final bool consentSelfAudit;
  final bool hasCompletedOnboarding;
  final DateTime createdAt;
  final DateTime? updatedAt;

  IdentityProfile copyWith({
    String? mainIdentifier,
    String? fullName,
    List<String>? associatedUsernames,
    String? associatedEmail,
    String? phone,
    bool? consentSelfAudit,
    bool? hasCompletedOnboarding,
    DateTime? updatedAt,
  }) {
    return IdentityProfile(
      accountId: accountId,
      mainIdentifier: mainIdentifier ?? this.mainIdentifier,
      fullName: fullName ?? this.fullName,
      associatedUsernames: associatedUsernames != null
          ? List.unmodifiable(associatedUsernames)
          : this.associatedUsernames,
      associatedEmail: associatedEmail ?? this.associatedEmail,
      phone: phone ?? this.phone,
      consentSelfAudit: consentSelfAudit ?? this.consentSelfAudit,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'account_id': accountId,
        'main_identifier': mainIdentifier,
        if (fullName != null) 'full_name': fullName,
        'associated_usernames': associatedUsernames,
        if (associatedEmail != null) 'associated_email': associatedEmail,
        if (phone != null) 'phone': phone,
        'consent_self_audit': consentSelfAudit,
        'has_completed_onboarding': hasCompletedOnboarding,
        'created_at': createdAt.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  String serialize() => jsonEncode(toJson());

  static IdentityProfile? tryDeserialize(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        return IdentityProfile.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}
