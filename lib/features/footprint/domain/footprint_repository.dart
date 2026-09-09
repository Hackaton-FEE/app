import 'footprint_profile.dart';

abstract class FootprintRepository {
  Future<FootprintProfile> getProfile();
  Future<FootprintProfile> scanIdentity(String identity);
}
