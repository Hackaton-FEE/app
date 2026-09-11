import '../support/scan_form_test_helpers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fee_app/features/accounts/data/identity_storage.dart';
import 'package:fee_app/features/accounts/data/local_identity_profile_repository.dart';
import 'package:fee_app/features/accounts/domain/local_account.dart';
import 'package:fee_app/features/accounts/presentation/identity_profile_controller.dart';
import 'package:fee_app/features/accounts/presentation/profile_setup_page.dart';
import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:fee_app/features/footprint/domain/footprint_repository.dart';
import 'package:fee_app/features/footprint/presentation/footprint_controller.dart';

class _InMemoryStorage implements IdentityStorage {
  final _data = <String, String>{};
  @override
  Future<Map<String, String>> readAll() async => Map.of(_data);
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<void> delete(String key) async => _data.remove(key);
}

class _FakeFootprintRepository implements FootprintRepository {
  String? lastScannedIdentity;
  List<String>? lastUsernames;
  bool? lastConsent;
  String? lastEmail;

  @override
  Future<FootprintProfile> getProfile() async =>
      FootprintProfile.initial(targetIdentity: 'test@example.com');

  @override
  Future<FootprintProfile> scanIdentity(
    String identity, {
    List<String> associatedUsernames = const [],
    String? associatedEmail,
    bool consentSelfAudit = true,
  }) async {
    lastScannedIdentity = identity;
    lastUsernames = associatedUsernames;
    lastConsent = consentSelfAudit;
    lastEmail = associatedEmail;
    return FootprintProfile.initial(targetIdentity: identity);
  }
}

void main() {
  testWidgets('ProfileSetupPage renders initial onboarding form and fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _InMemoryStorage();
    final repo = LocalIdentityProfileRepository(storage: storage);
    final controller = IdentityProfileController(repo, accountId: 'acc-1');
    await controller.load();

    const account = LocalAccount(
      id: 'acc-1',
      name: 'Carlos Ruiz',
      email: 'carlos@example.com',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSetupPage(
          account: account,
          identityController: controller,
          isInitialOnboarding: true,
        ),
      ),
    );

    expect(find.text('Configura tu identidad a proteger'), findsOneWidget);
    expect(find.text('Carlos Ruiz'), findsNothing);
    expect(find.text('carlos@example.com'), findsOneWidget);
    expect(find.text('Guardar e Iniciar Auditoría'), findsOneWidget);
    expect(find.text('Configurar más tarde (iniciar en 0)'), findsOneWidget);
  });

  testWidgets(
    'Submitting form saves profile, triggers scan, and calls onCompleted',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = _InMemoryStorage();
      final repo = LocalIdentityProfileRepository(storage: storage);
      final controller = IdentityProfileController(repo, accountId: 'acc-1');
      await controller.load();

      final fakeFootprintRepo = _FakeFootprintRepository();
      final footprint = FootprintController(fakeFootprintRepo);

      const account = LocalAccount(
        id: 'acc-1',
        name: 'Ana López',
        email: 'ana@empresa.com',
      );

      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupPage(
            account: account,
            identityController: controller,
            footprintController: footprint,
            isInitialOnboarding: true,
            onCompleted: () => completed = true,
          ),
        ),
      );

      await fillScanContacts(tester, aliases: 'analopez');

      // Tap submit
      await tester.ensureVisible(find.text('Guardar e Iniciar Auditoría'));
      await tester.tap(find.text('Guardar e Iniciar Auditoría'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(controller.needsOnboarding, isFalse);
      expect(controller.profile?.mainIdentifier, 'ana@empresa.com');
      expect(controller.profile?.associatedUsernames, ['analopez']);
      expect(fakeFootprintRepo.lastScannedIdentity, '+12025550123');
      expect(fakeFootprintRepo.lastEmail, 'ana@empresa.com');
      expect(controller.profile?.phone, '+12025550123');
      expect(fakeFootprintRepo.lastUsernames, ['analopez']);
    },
  );

  testWidgets('Skip button satisfies onboarding with default zero-state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _InMemoryStorage();
    final repo = LocalIdentityProfileRepository(storage: storage);
    final controller = IdentityProfileController(repo, accountId: 'acc-2');
    await controller.load();

    const account = LocalAccount(
      id: 'acc-2',
      name: 'David',
      email: 'david@test.com',
    );

    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileSetupPage(
          account: account,
          identityController: controller,
          isInitialOnboarding: true,
          onCompleted: () => completed = true,
        ),
      ),
    );

    await tester.ensureVisible(
      find.text('Configurar más tarde (iniciar en 0)'),
    );
    await tester.tap(find.text('Configurar más tarde (iniciar en 0)'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(controller.needsOnboarding, isFalse);
    expect(controller.profile?.mainIdentifier, 'david@test.com');
    expect(controller.profile?.consentSelfAudit, isFalse);
  });

  testWidgets(
    'failed skip preserves corrupt profile and never completes onboarding',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = _InMemoryStorage();
      await storage.write('acc-corrupt', '{broken');
      final controller = IdentityProfileController(
        LocalIdentityProfileRepository(storage: storage),
        accountId: 'acc-corrupt',
      );
      addTearDown(controller.dispose);
      await controller.load();
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupPage(
            account: const LocalAccount(
              id: 'acc-corrupt',
              name: 'Etiqueta',
              email: '',
            ),
            identityController: controller,
            onCompleted: () => completed = true,
          ),
        ),
      );
      await tester.ensureVisible(
        find.text('Configurar más tarde (iniciar en 0)'),
      );
      await tester.tap(find.text('Configurar más tarde (iniciar en 0)'));
      await tester.pumpAndSettle();
      expect(completed, isFalse);
      expect(controller.needsOnboarding, isFalse);
      expect(await storage.read('acc-corrupt'), '{broken');
      expect(
        find.text('El perfil de identidad almacenado no es válido.'),
        findsOneWidget,
      );
      expect(find.byType(ProfileSetupPage), findsOneWidget);
    },
  );

  testWidgets(
    'an account label never pre-fills personal identity or grants scan consent',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = _InMemoryStorage();
      final controller = IdentityProfileController(
        LocalIdentityProfileRepository(storage: storage),
        accountId: 'label-only',
      );
      addTearDown(controller.dispose);
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupPage(
            account: const LocalAccount(
              id: 'label-only',
              name: 'Etiqueta privada',
              email: '',
            ),
            identityController: controller,
          ),
        ),
      );
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(field.controller!.text, isEmpty);
      }
      await tester.ensureVisible(
        find.text('Configurar más tarde (iniciar en 0)'),
      );
      await tester.tap(find.text('Configurar más tarde (iniciar en 0)'));
      await tester.pumpAndSettle();
      expect(controller.profile?.mainIdentifier, isEmpty);
      expect(controller.profile?.fullName, isNull);
      expect(controller.profile?.consentSelfAudit, isFalse);
    },
  );
}
