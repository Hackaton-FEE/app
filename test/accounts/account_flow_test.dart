import '../support/ready_identity_repository.dart';
import '../support/demo_guard_ai_repository.dart';

import 'package:fee_app/features/footprint/data/local_scan_history_repository.dart';

import '../footprint/fake_scan_history_storage.dart';

import 'package:fee_app/app/app.dart';

import '../support/demo_account_repository.dart';

import 'package:fee_app/features/accounts/domain/local_account.dart';
import 'package:fee_app/features/accounts/presentation/account_picker_page.dart';
import 'package:fee_app/features/cases/data/local_case_repository.dart';

import '../support/mock_footprint_repository.dart';

import 'package:fee_app/features/footprint/presentation/dashboard_page.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_case_storage.dart';

const _first = LocalAccount(
  id: 'profile-first',
  name: 'Cuenta personal',
  email: 'personal@example.invalid',
);
const _second = LocalAccount(
  id: 'profile-second',
  name: 'Perfil alternativo',
  email: 'otra@example.invalid',
);

void main() {
  late DemoAccountRepository accounts;
  late FakeCaseStorage cases;

  setUp(() {
    accounts = DemoAccountRepository(initialAccounts: [_first, _second]);
    cases = FakeCaseStorage();
  });

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      FeeApp(
        guardAiRepositoryFactory: (_) => DemoGuardAiRepository(),
        identityProfileRepository: ReadyIdentityRepository(),
        scanHistoryRepositoryFactory: (_) =>
            LocalScanHistoryRepository(storage: FakeScanHistoryStorage()),
        accountRepository: accounts,
        repository: LocalCaseRepository(storage: cases),
        footprintRepositoryFactory: (account) =>
            MockFootprintRepository(targetIdentity: account.email),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> revealAndTap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, LocalAccount account) =>
      revealAndTap(tester, find.byKey(Key('account-${account.id}')));

  Future<void> returnToPicker(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('dashboard-profile-button')));
    await tester.pumpAndSettle();
    await revealAndTap(tester, find.byKey(const Key('profile-accounts')));
    expect(find.byType(AccountPickerPage), findsOneWidget);
  }

  Future<void> openGuardAi(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('dashboard-guardai-fab')));
    await tester.pumpAndSettle();
    expect(find.byType(GuardAiPage), findsOneWidget);
  }

  testWidgets('opening offers profiles and selecting one enters directly', (
    tester,
  ) async {
    await start(tester);
    expect(find.byType(AccountPickerPage), findsOneWidget);
    expect(find.byType(DashboardPage), findsNothing);
    expect(find.byType(TextField), findsNothing);

    await select(tester, _first);
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.byType(AccountPickerPage), findsNothing);
    expect(find.byKey(const Key('dashboard-guardai-fab')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-report-fab')), findsNothing);

    await returnToPicker(tester);
    await select(tester, _second);
    expect(find.byType(DashboardPage), findsOneWidget);
    await tester.tap(find.byKey(const Key('dashboard-profile-button')));
    await tester.pumpAndSettle();
    expect(find.text(_second.name), findsOneWidget);
    expect(find.text(_second.email), findsWidgets);
    expect(cases.records, isEmpty);
  });

  testWidgets(
    'default landing offers only the configured account and no help',
    (tester) async {
      accounts = DemoAccountRepository();
      await start(tester);
      expect(find.text('pedro.gomez@gmail.com'), findsOneWidget);
      expect(find.byKey(const Key('account-demo-other')), findsNothing);
      expect(find.byKey(const Key('account-add-existing')), findsNothing);
      expect(find.byKey(const Key('account-create')), findsNothing);
      expect(find.byTooltip('Ayuda de uso'), findsNothing);
      expect(find.text('Así funciona'), findsNothing);
      await select(tester, (await accounts.listAccounts()).single);
      expect(find.text('pedro.gomez@gmail.com'), findsOneWidget);
      await returnToPicker(tester);
      expect(await accounts.listAccounts(), hasLength(1));
    },
  );

  testWidgets('an empty picker offers retry without creating a profile', (
    tester,
  ) async {
    accounts = DemoAccountRepository(initialAccounts: []);
    await start(tester);
    await revealAndTap(tester, find.text('Reintentar'));
    expect(find.byType(AccountPickerPage), findsOneWidget);
    expect(await accounts.listAccounts(), isEmpty);
    expect(find.byKey(const Key('account-create')), findsNothing);
  });

  testWidgets('recreating the app asks for a profile again', (tester) async {
    await start(tester);
    await select(tester, _first);
    expect(find.byType(DashboardPage), findsOneWidget);
    final profiles = await accounts.listAccounts();

    // Reusing an in-memory repository checks composition, not process restart.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await start(tester);
    expect(find.byType(AccountPickerPage), findsOneWidget);
    expect(find.byType(DashboardPage), findsNothing);
    for (final profile in profiles) {
      expect(find.byKey(Key('account-${profile.id}')), findsOneWidget);
    }
  });

  testWidgets('scanning one profile does not change another profile identity', (
    tester,
  ) async {
    await start(tester);
    await select(tester, _first);
    await tester.tap(find.byKey(const Key('dashboard-scan-fab')));
    await tester.pumpAndSettle();
    const scanned = 'identidad.nueva@example.invalid';
    await tester.enterText(
      find.byKey(const Key('scan-identity-field')),
      scanned,
    );
    await revealAndTap(
      tester,
      find.byKey(const Key('start-scan-submit-button')),
    );
    expect(find.text(scanned), findsOneWidget);

    await returnToPicker(tester);
    await select(tester, _second);
    expect(find.text(scanned), findsNothing);
    expect(find.text(_second.email), findsOneWidget);

    await returnToPicker(tester);
    await select(tester, _first);
    expect(find.text(scanned), findsOneWidget);
  });

  testWidgets('GuardAI keeps each profile conversation and draft separate', (
    tester,
  ) async {
    await start(tester);
    await select(tester, _first);
    await openGuardAi(tester);
    final input = find.byType(TextField);
    const message = 'Quiero revisar mi privacidad';
    const draft = 'Borrador de la primera cuenta';
    await tester.ensureVisible(input);
    await tester.enterText(input, message);
    await revealAndTap(tester, find.byKey(const Key('guard-ai-send')));
    await tester.scrollUntilVisible(
      find.text(message),
      -160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    await tester.ensureVisible(input);
    await tester.enterText(input, draft);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Regresar al inicio'));
    await tester.pumpAndSettle();
    await returnToPicker(tester);
    await select(tester, _second);
    await openGuardAi(tester);
    expect(find.text(message), findsNothing);
    await tester.ensureVisible(find.byType(TextField, skipOffstage: false));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Regresar al inicio'));
    await tester.pumpAndSettle();
    await returnToPicker(tester);
    await select(tester, _first);
    await openGuardAi(tester);
    expect(find.text(message), findsOneWidget);
    await tester.ensureVisible(find.byType(TextField, skipOffstage: false));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, draft);
    expect(cases.records, isEmpty);
  });
}
