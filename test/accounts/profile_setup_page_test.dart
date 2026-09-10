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

  @override
  Future<FootprintProfile> getProfile() async =>
      FootprintProfile.initial(targetIdentity: 'test@example.com');

  @override
  Future<FootprintProfile> scanIdentity(
    String identity, {
    List<String> associatedUsernames = const [],
    bool consentSelfAudit = true,
  }) async {
    lastScannedIdentity = identity;
    lastUsernames = associatedUsernames;
    lastConsent = consentSelfAudit;
    return FootprintProfile.initial(targetIdentity: identity);
  }
}

void main() {
  testWidgets('ProfileSetupPage renders initial onboarding form and fields',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _InMemoryStorage();
    final repo = LocalIdentityProfileRepository(storage: storage);
    final controller = IdentityProfileController(
      repo,
      accountId: 'acc-1',
      isDemo: false,
    );
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
    expect(find.text('Carlos Ruiz'), findsNWidgets(2));
    expect(find.text('Guardar e Iniciar Auditoría'), findsOneWidget);
    expect(
      find.text('Configurar más tarde (iniciar en 0)'),
      findsOneWidget,
    );
  });

  testWidgets('Can add and delete associated usernames', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _InMemoryStorage();
    final repo = LocalIdentityProfileRepository(storage: storage);
    final controller = IdentityProfileController(
      repo,
      accountId: 'acc-1',
      isDemo: false,
    );
    await controller.load();

    const account = LocalAccount(
      id: 'acc-1',
      name: 'Ana',
      email: 'ana@test.com',
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

    final inputFinder =
        find.widgetWithText(TextField, 'Ej. jdoe, pepito_dev');
    await tester.enterText(inputFinder, 'anita_dev');
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();

    expect(find.text('@anita_dev'), findsOneWidget);

    // Delete chip
    await tester.tap(find.byIcon(Icons.clear).last);
    await tester.pump();

    expect(find.text('@anita_dev'), findsNothing);
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
    final controller = IdentityProfileController(
      repo,
      accountId: 'acc-1',
      isDemo: false,
    );
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

    // Add handle
    final inputFinder =
        find.widgetWithText(TextField, 'Ej. jdoe, pepito_dev');
    await tester.enterText(inputFinder, 'analopez');
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();

    // Tap submit
    await tester.tap(find.text('Guardar e Iniciar Auditoría'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(controller.needsOnboarding, isFalse);
    expect(controller.profile?.mainIdentifier, 'Ana López');
    expect(controller.profile?.associatedUsernames, ['analopez']);
    expect(fakeFootprintRepo.lastScannedIdentity, 'Ana López');
    expect(fakeFootprintRepo.lastUsernames, ['analopez']);
  });

  testWidgets('Skip button satisfies onboarding with default zero-state',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _InMemoryStorage();
    final repo = LocalIdentityProfileRepository(storage: storage);
    final controller = IdentityProfileController(
      repo,
      accountId: 'acc-2',
      isDemo: false,
    );
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

    await tester.tap(find.text('Configurar más tarde (iniciar en 0)'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(controller.needsOnboarding, isFalse);
    expect(controller.profile?.mainIdentifier, 'David');
  });
}
