import 'package:fee_app/features/accounts/domain/identity_profile.dart';
import 'package:fee_app/features/accounts/domain/identity_profile_repository.dart';

/// Widget tests start after onboarding unless they explicitly test that flow.
class ReadyIdentityRepository implements IdentityProfileRepository {
  final _profiles = <String, IdentityProfile>{};

  @override
  Future<IdentityProfile?> getProfile(String accountId) async =>
      _profiles[accountId] ??
      IdentityProfile(
        accountId: accountId,
        mainIdentifier: 'fixture@example.invalid',
        createdAt: DateTime.utc(2026, 9, 10),
      );

  @override
  Future<void> saveProfile(IdentityProfile profile) async {
    _profiles[profile.accountId] = profile;
  }

  @override
  Future<void> deleteProfile(String accountId) async {
    _profiles.remove(accountId);
  }
}
