import 'scan_history_entry.dart';

abstract class ScanHistoryRepository {
  Future<List<ScanHistoryEntry>> loadHistory();
  Future<void> saveScan(ScanHistoryEntry entry);
  Future<void> deleteScan(String id);
  Future<void> pruneExpired();
  Future<void> clearAll();
}
