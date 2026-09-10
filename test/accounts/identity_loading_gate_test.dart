import 'dart:async';

import 'package:fee_app/app/app.dart';
import 'package:fee_app/features/accounts/data/identity_storage.dart';
import 'package:fee_app/features/accounts/data/local_identity_profile_repository.dart';
import 'package:fee_app/features/accounts/domain/identity_profile.dart';
import 'package:fee_app/features/accounts/domain/local_account.dart';
import 'package:fee_app/features/accounts/presentation/account_picker_page.dart';
import 'package:fee_app/features/accounts/presentation/profile_setup_page.dart';
import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:fee_app/features/footprint/data/local_scan_history_repository.dart';
import 'package:fee_app/features/footprint/data/unavailable_footprint_repository.dart';
import 'package:fee_app/features/footprint/presentation/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_case_storage.dart';
import '../footprint/fake_scan_history_storage.dart';
import '../support/demo_account_repository.dart';

const _account = LocalAccount(
  id: 'identity-gate-test',
  name: 'Cuenta de prueba',
  email: 'test@example.invalid',
);

class _IdentityStorage implements IdentityStorage {
  _IdentityStorage(this.raw);
  final String raw;
  Completer<void>? readGate;
  bool failRead = false;
  int reads = 0;
  int writes = 0;
  int deletes = 0;

  @override
  Future<String?> read(String accountId) async {
    reads++;
    if (readGate != null) await readGate!.future;
    if (failRead) throw StateError('Storage unavailable');
    return raw;
  }

  @override
  Future<Map<String, String>> readAll() async => {_account.id: raw};

  @override
  Future<void> write(String accountId, String value) async => writes++;

  @override
  Future<void> delete(String accountId) async => deletes++;
}

Future<void> _start(WidgetTester tester, _IdentityStorage storage) async {
  await tester.pumpWidget(
    FeeApp(
      accountRepository: DemoAccountRepository(initialAccounts: [_account]),
      identityProfileRepository: LocalIdentityProfileRepository(
        storage: storage,
      ),
      repository: LocalCaseRepository(storage: FakeCaseStorage()),
      footprintRepositoryFactory: (_) => const UnavailableFootprintRepository(
        targetIdentity: 'test@example.invalid',
      ),
      scanHistoryRepositoryFactory: (_) =>
          LocalScanHistoryRepository(storage: FakeScanHistoryStorage()),
    ),
  );
  await tester.pumpAndSettle();
  final account = find.byKey(const Key('account-identity-gate-test'));
  await tester.ensureVisible(account);
  await tester.tap(account);
  await tester.pump();
}

void main() {
  testWidgets(
    'loading and corrupt identity block dashboard and preserve storage on retry',
    (tester) async {
      final storage = _IdentityStorage('{invalid-json')
        ..readGate = Completer<void>();
      await _start(tester, storage);
      expect(find.byKey(const Key('identity-profile-loading')), findsOneWidget);
      expect(find.byType(DashboardPage), findsNothing);
      expect(find.byType(ProfileSetupPage), findsNothing);

      storage.readGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('identity-profile-error')), findsOneWidget);
      expect(find.byType(DashboardPage), findsNothing);
      expect(find.byType(ProfileSetupPage), findsNothing);
      final original = await storage.readAll();
      await tester.tap(find.byKey(const Key('identity-profile-retry')));
      await tester.pumpAndSettle();
      expect(storage.reads, 2);
      expect(find.byKey(const Key('identity-profile-error')), findsOneWidget);
      expect(await storage.readAll(), original);
      expect(storage.writes, 0);
      expect(storage.deletes, 0);

      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();

      final signOut = find.byKey(const Key('identity-profile-sign-out'));
      await tester.ensureVisible(signOut);
      await tester.tap(signOut);
      await tester.pumpAndSettle();
      expect(find.byType(AccountPickerPage), findsOneWidget);
      expect(await storage.readAll(), original);
    },
  );

  testWidgets('retry enters dashboard only after a successful identity read', (
    tester,
  ) async {
    final raw = IdentityProfile(
      accountId: _account.id,
      mainIdentifier: _account.email,
      hasCompletedOnboarding: true,
      createdAt: DateTime.utc(2026, 9, 10),
    ).serialize();
    final storage = _IdentityStorage(raw)..failRead = true;
    await _start(tester, storage);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('identity-profile-error')), findsOneWidget);
    expect(find.byType(DashboardPage), findsNothing);
    expect(find.byType(ProfileSetupPage), findsNothing);

    storage.failRead = false;
    await tester.tap(find.byKey(const Key('identity-profile-retry')));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.byKey(const Key('identity-profile-error')), findsNothing);
    expect(storage.writes, 0);
    expect(storage.deletes, 0);
    expect(await storage.readAll(), {_account.id: raw});
  });
}
