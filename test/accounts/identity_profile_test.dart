import 'dart:convert';

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
      final recreated = LocalIdentityProfileRepository(storage: storage);
      final retrieved = await recreated.getProfile('acc-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.mainIdentifier, 'user@example.com');
      expect(retrieved.associatedUsernames, ['user_x']);

      await repo.deleteProfile('acc-1');
      expect(await repo.getProfile('acc-1'), isNull);
    });

    test(
      'corrupt data blocks reads and changes without replacing the original',
      () async {
        final storage = _InMemoryIdentityStorage();
        await storage.write('acc-bad', '{not valid json');
        final repo = LocalIdentityProfileRepository(storage: storage);

        await expectLater(repo.getProfile('acc-bad'), throwsFormatException);
        final replacement = IdentityProfile(
          accountId: 'acc-bad',
          mainIdentifier: 'test@example.invalid',
          createdAt: DateTime.utc(2026, 9, 10),
        );
        await expectLater(repo.saveProfile(replacement), throwsFormatException);
        await expectLater(repo.deleteProfile('acc-bad'), throwsFormatException);
        expect(await storage.read('acc-bad'), '{not valid json');
      },
    );
  });

  group('Invalid stored identity', () {
    final valid = IdentityProfile(
      accountId: 'acc-invalid',
      mainIdentifier: 'test@example.invalid',
      consentSelfAudit: false,
      createdAt: DateTime.utc(2026, 9, 10),
    ).toJson();
    final invalidCases = <String, dynamic>{
      'created_at': '2026-02-30T10:00:00Z',
      'updated_at': 'not a date',
      'consent_self_audit': 'true',
      'has_completed_onboarding': null,
      'associated_usernames': [123],
      'full_name': false,
      'account_id': 'another-account',
    };
    for (final entry in invalidCases.entries) {
      test('rejects ${entry.key} without modifying the record', () async {
        final raw = jsonEncode({...valid, entry.key: entry.value});
        final storage = _InMemoryIdentityStorage();
        await storage.write('acc-invalid', raw);
        final repo = LocalIdentityProfileRepository(storage: storage);
        await expectLater(
          repo.getProfile('acc-invalid'),
          throwsFormatException,
        );
        expect(await storage.read('acc-invalid'), raw);
      });
    }
    for (final field in [
      'created_at',
      'consent_self_audit',
      'has_completed_onboarding',
    ]) {
      test('missing $field never becomes a date or consent default', () {
        final incomplete = Map<String, dynamic>.from(valid)..remove(field);
        expect(
          () => IdentityProfile.fromJson(incomplete),
          throwsFormatException,
        );
      });
    }
    for (final raw in ['', ' ', '[]', 'x' * (32 * 1024 + 1)]) {
      test(
        'present invalid record of ${raw.length} characters is not absence',
        () async {
          final storage = _InMemoryIdentityStorage();
          await storage.write('acc-invalid', raw);
          final repo = LocalIdentityProfileRepository(storage: storage);
          await expectLater(
            repo.getProfile('acc-invalid'),
            throwsFormatException,
          );
          expect(await storage.read('acc-invalid'), raw);
        },
      );
    }
    test('input aliases and returned collections cannot mutate a profile', () {
      final aliases = ['alias'];
      final profile = IdentityProfile(
        accountId: 'test',
        mainIdentifier: '',
        associatedUsernames: aliases,
        createdAt: DateTime.utc(2026, 9, 10),
      );
      aliases.clear();
      expect(profile.associatedUsernames, ['alias']);
      expect(() => profile.associatedUsernames.clear(), throwsUnsupportedError);
    });
  });

  group('IdentityProfileController', () {
    test('failed load cannot turn a corrupt profile into onboarding', () async {
      final storage = _InMemoryIdentityStorage();
      await storage.write('test', '{}');
      final controller = IdentityProfileController(
        LocalIdentityProfileRepository(storage: storage),
        accountId: 'test',
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.error, isNotNull);
      expect(controller.isLoaded, isFalse);
      expect(controller.needsOnboarding, isFalse);
      expect(await controller.skipOnboarding(identifier: ''), isFalse);
      expect(await storage.read('test'), '{}');
    });

    test('a fresh account requires onboarding', () async {
      final storage = _InMemoryIdentityStorage();
      final repo = LocalIdentityProfileRepository(storage: storage);
      final controller = IdentityProfileController(repo, accountId: 'demo-1');

      await controller.load();
      expect(controller.needsOnboarding, isTrue);
    });

    test(
      'new non-demo account requires onboarding until saved or skipped',
      () async {
        final storage = _InMemoryIdentityStorage();
        final repo = LocalIdentityProfileRepository(storage: storage);
        final controller = IdentityProfileController(
          repo,
          accountId: 'user-123',
        );

        await controller.load();
        expect(controller.needsOnboarding, isTrue);

        await controller.skipOnboarding(email: 'test@domain.com');
        expect(controller.needsOnboarding, isFalse);
        expect(controller.profile?.mainIdentifier, 'test@domain.com');
        expect(controller.profile?.consentSelfAudit, isFalse);
      },
    );

    test('save updates profile and satisfies onboarding', () async {
      final storage = _InMemoryIdentityStorage();
      final repo = LocalIdentityProfileRepository(storage: storage);
      final controller = IdentityProfileController(repo, accountId: 'user-456');

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
