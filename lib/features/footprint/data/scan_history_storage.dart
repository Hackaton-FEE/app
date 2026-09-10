abstract class ScanHistoryStorage {
  Future<Map<String, String>> readAll();
  Future<void> write(String id, String value);
  Future<void> delete(String id);
}
