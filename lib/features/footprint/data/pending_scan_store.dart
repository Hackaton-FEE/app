import 'dart:convert';

import 'scan_history_storage.dart';

class PendingScan {
  const PendingScan(this.id, this.identity);
  final String id;
  final String identity;
}

/// The adapter's prefix must be account-specific and separate from history.
class PendingScanStore {
  PendingScanStore(this.storage);
  final ScanHistoryStorage storage;

  Future<PendingScan?> load() async {
    final records = await storage.readAll();
    if (records.isEmpty) return null;
    try {
      if (records.length != 1 || !records.containsKey('active')) {
        throw const FormatException();
      }
      final json = jsonDecode(records['active']!) as Map<String, dynamic>;
      if (json['version'] != 1 ||
          json['scan_id'] is! String ||
          (json['scan_id'] as String).trim().isEmpty ||
          json['identity'] is! String ||
          (json['identity'] as String).trim().isEmpty) {
        throw const FormatException();
      }
      return PendingScan(json['scan_id'] as String, json['identity'] as String);
    } catch (_) {
      throw const FormatException(
        'No se puede leer el escaneo pendiente. Sus datos se conservan.',
      );
    }
  }

  Future<void> save(PendingScan scan) => storage.write(
    'active',
    jsonEncode({'version': 1, 'scan_id': scan.id, 'identity': scan.identity}),
  );

  Future<void> clear() => storage.delete('active');
}
