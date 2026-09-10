import 'package:fee_app/features/footprint/data/scan_history_storage.dart';

class FakeScanHistoryStorage implements ScanHistoryStorage {
  FakeScanHistoryStorage([Map<String, String>? initialData])
    : _data = Map.from(initialData ?? {});

  final Map<String, String> _data;
  bool shouldFail = false;
  bool failDelete = false;

  @override
  Future<Map<String, String>> readAll() async {
    if (shouldFail) throw StateError('Storage failed');
    return Map.unmodifiable(_data);
  }

  @override
  Future<void> write(String id, String value) async {
    if (shouldFail) throw StateError('Storage failed');
    _data[id] = value;
  }

  @override
  Future<void> delete(String id) async {
    if (failDelete) throw StateError('Delete failed');
    if (shouldFail) throw StateError('Storage failed');
    _data.remove(id);
  }
}
