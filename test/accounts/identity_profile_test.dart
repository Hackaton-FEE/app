import 'package:flutter_test/flutter_test.dart';
import 'package:fee_app/features/accounts/data/identity_storage.dart';
import 'package:fee_app/features/accounts/data/local_identity_profile_repository.dart';
import 'package:fee_app/features/accounts/domain/identity_profile.dart';
import 'package:fee_app/features/accounts/presentation/identity_profile_controller.dart';

class _InMemoryIdentityStorage implements IdentityStorage {
  final _data = <String, String>{};

  @override
  Future<Map<String, String>> readAll() async => Map.of(_data);

  @override
  Future<String?> read(String accountId) async => _data[accountId];

  @override
  Future<void> write(String accountId, String value) async {
    _data[accountId] = value;
  }

  @override
  Future<void> delete(String accountId) async {
    _data.remove(accountId);
  }
}

void main() {
  group('IdentityProfile', () {
    test('serializes and deserializes correctly', () {
      final now = DateTime.now();
      final profile = IdentityProfile(
        accountId: 'acc-123',
        mainIdentifier: 'pepe@gmail.com',
        fullName: 'Pepe Grillo',
        associatedUsernames: const ['pepito', 'pepito_sec'],
        associatedEmail: 'pepe@gmail.com',
        phone: '+1234567890',
        consentSelfAudit: true,
        hasCompletedOnboarding: true,
        createdAt: now,
      );

      final json = profile.toJson();
      final restored = IdentityProfile.fromJson(json);

      expect(restored.accountId, 'acc-123');
      expect(restored.mainIdentifier, 'pepe@gmail.com');
      expect(restored.fullName, 'Pepe Grillo');
      expect(restored.associatedUsernames, ['pepito', 'pepito_sec']);
      expect(restored.phone, '+1234567890');
      expect(restored.consentSelfAudit, isTrue);
      expect(restored.hasCompletedOnboarding, isTrue);
    });

    test('copyWith updates fields correctly', () {
      final profile = IdentityProfile(
        accountId: 'acc-1',
        mainIdentifier: 'original@test.com',
        createdAt: DateTime.now(),
      );

      final updated = profile.copyWith(
        mainIdentifier: 'updated@test.com',
        associatedUsernames: ['user1'],
      );

      expect(updated.mainIdentifier, 'updated@test.com');
      expect(updated.associatedUsernames, ['user1']);
      expect(updated.accountId, 'acc-1');
    });
  });

  group('LocalIdentityProfileRepository', () {
    test('saves, retrieves, and deletes profile', () async {
      final storage = _InMemoryIdentityStorage();
      final repo = LocalIdentityProfileRepository(storage: storage);

      expect(await repo.getProfile('acc-1'), isNull);

      final profile = IdentityProfile(
        accountId: 'acc-1',
        mainIdentifier: 'user@example.com',
        associatedUsernames: const ['user_x'],
        createdAt: DateTime.now(),
      );

      await repo.saveProfile(profile);
      final retrieved = await repo.getProfile('acc-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.mainIdentifier, 'user@example.com');
      expect(retrieved.associatedUsernames, ['user_x']);

      await repo.deleteProfile('acc-1');
      expect(await repo.getProfile('acc-1'), isNull);
    });

    test('handles corrupt json gracefully by returning null', () async {
      final storage = _InMemoryIdentityStorage();
      await storage.write('acc-bad', '{not valid json');
      final repo = LocalIdentityProfileRepository(storage: storage);

      final result = await repo.getProfile('acc-bad');
      expect(result, isNull);
    });
  });

  group('IdentityProfileController', () {
    test('demo account never needs onboarding', () async {
      final storage = _InMemoryIdentityStorage();
      final repo = LocalIdentityProfileRepository(storage: storage);
      final controller = IdentityProfileController(
        repo,
        accountId: 'demo-1',
        isDemo: true,
      );

      await controller.load();
      expect(controller.needsOnboarding, isFalse);
    });

    test('new non-demo account requires onboarding until saved or skipped', () async {
      final storage = _InMemoryIdentityStorage();
      final repo = LocalIdentityProfileRepository(storage: storage);
      final controller = IdentityProfileController(
        repo,
        accountId: 'user-123',
        isDemo: false,
      );

      await controller.load();
      expect(controller.needsOnboarding, isTrue);

      await controller.skipOnboarding(email: 'test@domain.com');
      expect(controller.needsOnboarding, isFalse);
      expect(controller.profile?.mainIdentifier, 'test@domain.com');
    });

    test('save updates profile and satisfies onboarding', () async {
      final storage = _InMemoryIdentityStorage();
      final repo = LocalIdentityProfileRepository(storage: storage);
      final controller = IdentityProfileController(
        repo,
        accountId: 'user-456',
        isDemo: false,
      );

      await controller.load();
      expect(controller.needsOnboarding, isTrue);

      final profile = IdentityProfile(
        accountId: 'user-456',
        mainIdentifier: 'custom@domain.com',
        associatedUsernames: const ['custom_handle'],
        hasCompletedOnboarding: true,
        createdAt: DateTime.now(),
      );

      final ok = await controller.save(profile);
      expect(ok, isTrue);
      expect(controller.needsOnboarding, isFalse);
      expect(controller.profile?.mainIdentifier, 'custom@domain.com');
      expect(controller.profile?.associatedUsernames, ['custom_handle']);
    });
  });
}
