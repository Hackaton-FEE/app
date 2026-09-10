import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'scan_history_storage.dart';

class FlutterSecureScanStorage implements ScanHistoryStorage {
  FlutterSecureScanStorage({
    this.prefix = 'fee.scan.v1.',
    FlutterSecureStorage? storage,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: androidOptions,
             iOptions: iosOptions,
           ) {
    if (prefix.isEmpty) {
      throw ArgumentError('A storage prefix is required.');
    }
  }

  static const androidOptions = AndroidOptions(
    resetOnError: false,
    storageNamespace: 'fee_scans',
  );
  static const iosOptions = IOSOptions(
    accountName: 'org.hackatonfee.feeApp.scans',
    accessibility: KeychainAccessibility.unlocked_this_device,
    synchronizable: false,
  );

  final String prefix;
  final FlutterSecureStorage _storage;

  @override
  Future<Map<String, String>> readAll() async {
    final entries = await _storage.readAll();
    return {
      for (final entry in entries.entries)
        if (entry.key.startsWith(prefix))
          entry.key.substring(prefix.length): entry.value,
    };
  }

  @override
  Future<void> write(String id, String value) =>
      _storage.write(key: '$prefix$id', value: value);

  @override
  Future<void> delete(String id) => _storage.delete(key: '$prefix$id');
}
