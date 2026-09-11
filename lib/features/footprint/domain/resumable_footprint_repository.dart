import 'footprint_profile.dart';
import 'footprint_repository.dart';

abstract interface class ResumableFootprintRepository
    implements FootprintRepository {
  Future<FootprintProfile?> resumePendingScan();
  Future<void> acknowledgeScan(String scanId);
  void setForeground(bool foreground);
}
