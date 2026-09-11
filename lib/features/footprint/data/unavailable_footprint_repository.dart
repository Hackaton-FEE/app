import '../domain/footprint_profile.dart';
import '../domain/footprint_repository.dart';

class UnavailableFootprintRepository implements FootprintRepository {
  const UnavailableFootprintRepository({required this.targetIdentity});
  final String targetIdentity;

  @override
  Future<FootprintProfile> getProfile() async =>
      FootprintProfile.initial(targetIdentity: targetIdentity);

  @override
  Future<FootprintProfile> scanIdentity(
    String identity, {
    List<String> associatedUsernames = const [],
    String? associatedEmail,
    bool consentSelfAudit = true,
  }) async => throw const FormatException(
    'Inicia una sesión en el servidor para realizar el escaneo.',
  );
}
