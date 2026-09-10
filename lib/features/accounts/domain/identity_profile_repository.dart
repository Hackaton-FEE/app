import 'identity_profile.dart';

/// Contrato para la persistencia del perfil de identidad a auditar por cuenta.
abstract class IdentityProfileRepository {
  Future<IdentityProfile?> getProfile(String accountId);
  Future<void> saveProfile(IdentityProfile profile);
  Future<void> deleteProfile(String accountId);
}
