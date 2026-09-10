import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'identity_storage.dart';

class FlutterSecureIdentityStorage implements IdentityStorage {
  FlutterSecureIdentityStorage({
    this.prefix = 'fee.identity.v1.',
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
    storageNamespace: 'fee_identity',
  );
  static const iosOptions = IOSOptions(
    accountName: 'org.hackatonfee.feeApp.identity',
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
  Future<String?> read(String key) => _storage.read(key: '$prefix$key');

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: '$prefix$key', value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: '$prefix$key');
}
