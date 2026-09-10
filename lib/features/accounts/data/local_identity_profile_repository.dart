import 'dart:convert';

import '../domain/identity_profile.dart';
import '../domain/identity_profile_repository.dart';
import 'identity_storage.dart';

class LocalIdentityProfileRepository implements IdentityProfileRepository {
  LocalIdentityProfileRepository({required this.storage});

  final IdentityStorage storage;
  static const maxRecordBytes = 32 * 1024;
  Future<void>? _pending;

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _pending == null
        ? operation()
        : _pending!.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  IdentityProfile _decode(String accountId, String raw) {
    try {
      if (utf8.encode(raw).length > maxRecordBytes) {
        throw const FormatException();
      }
      final profile = IdentityProfile.deserialize(raw);
      if (profile.accountId != accountId) throw const FormatException();
      return profile;
    } catch (_) {
      throw const FormatException(
        'El perfil de identidad almacenado no es válido.',
      );
    }
  }

  Future<IdentityProfile?> _read(String accountId) async {
    final raw = await storage.read(accountId);
    return raw == null ? null : _decode(accountId, raw);
  }

  @override
  Future<IdentityProfile?> getProfile(String accountId) =>
      _enqueue(() => _read(accountId));

  @override
  Future<void> saveProfile(IdentityProfile profile) => _enqueue(() async {
    final serialized = profile.serialize();
    _decode(profile.accountId, serialized);
    // An unreadable existing record must never become a fresh profile.
    await _read(profile.accountId);
    await storage.write(profile.accountId, serialized);
  });

  @override
  Future<void> deleteProfile(String accountId) => _enqueue(() async {
    await _read(accountId);
    await storage.delete(accountId);
  });
}
