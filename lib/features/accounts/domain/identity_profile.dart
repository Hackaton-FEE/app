import 'dart:convert';

import '../../../shared/domain/profile_date.dart';

/// Perfil de identidad personal monitoreada para auditorías de huella OSINT.
class IdentityProfile {
  IdentityProfile({
    required this.accountId,
    required this.mainIdentifier,
    this.fullName,
    Iterable<String> associatedUsernames = const [],
    this.associatedEmail,
    this.phone,
    this.consentSelfAudit = true,
    this.hasCompletedOnboarding = true,
    required this.createdAt,
    this.updatedAt,
  }) : associatedUsernames = List.unmodifiable(associatedUsernames);

  factory IdentityProfile.fromJson(Map<String, dynamic> json) {
    try {
      final accountId = json['account_id'] as String;
      if (accountId.trim().isEmpty) throw const FormatException();
      final usernames = (json['associated_usernames'] as List).cast<String>();
      if (usernames.any((value) => value.trim().isEmpty)) {
        throw const FormatException();
      }
      return IdentityProfile(
        accountId: accountId,
        mainIdentifier: json['main_identifier'] as String,
        fullName: json['full_name'] as String?,
        associatedUsernames: usernames,
        associatedEmail: json['associated_email'] as String?,
        phone: json['phone'] as String?,
        consentSelfAudit: json['consent_self_audit'] as bool,
        hasCompletedOnboarding: json['has_completed_onboarding'] as bool,
        createdAt: parseProfileDate(json['created_at']),
        updatedAt: json['updated_at'] == null
            ? null
            : parseProfileDate(json['updated_at']),
      );
    } catch (_) {
      throw const FormatException('El perfil de identidad no es válido.');
    }
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
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
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

  static IdentityProfile deserialize(String rawJson) {
    try {
      return IdentityProfile.fromJson(
        jsonDecode(rawJson) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const FormatException('El perfil de identidad no es válido.');
    }
  }
}
