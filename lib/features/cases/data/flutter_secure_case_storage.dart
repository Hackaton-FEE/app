import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'case_storage.dart';

/// Bounded case metadata in Keychain / Android encrypted storage.
///
/// Each value is one JSON record, not the whole collection. This is intended for
/// small local collections, without attachments. A growing dataset should move
/// to an encrypted database with an explicit, non-destructive migration.
class FlutterSecureCaseStorage implements CaseStorage {
  FlutterSecureCaseStorage({
    this.prefix = 'fee.case.v1.',
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
    storageNamespace: 'fee_cases',
  );
  static const iosOptions = IOSOptions(
    accountName: 'org.hackatonfee.feeApp.cases',
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
