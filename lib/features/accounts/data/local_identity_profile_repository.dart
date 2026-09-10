import 'dart:convert';

import '../domain/identity_profile.dart';
import '../domain/identity_profile_repository.dart';
import 'identity_storage.dart';

class LocalIdentityProfileRepository implements IdentityProfileRepository {
  LocalIdentityProfileRepository({required this.storage});

  final IdentityStorage storage;
  static const maxRecordBytes = 32 * 1024;

  @override
  Future<IdentityProfile?> getProfile(String accountId) async {
    final raw = await storage.read(accountId);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      if (utf8.encode(raw).length > maxRecordBytes) return null;
      return IdentityProfile.tryDeserialize(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveProfile(IdentityProfile profile) async {
    final serialized = profile.serialize();
    if (utf8.encode(serialized).length > maxRecordBytes) {
      throw const FormatException('El tamaño del perfil supera el límite de seguridad.');
    }
    await storage.write(profile.accountId, serialized);
  }

  @override
  Future<void> deleteProfile(String accountId) async {
    await storage.delete(accountId);
  }
}
