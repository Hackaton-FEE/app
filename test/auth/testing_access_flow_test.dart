import 'dart:async';
import 'dart:convert';

import 'package:fee_app/app/app.dart';
import 'package:fee_app/features/accounts/domain/identity_profile.dart';
import 'package:fee_app/features/accounts/domain/identity_profile_repository.dart';
import 'package:fee_app/features/accounts/presentation/account_picker_page.dart';
import 'package:fee_app/features/accounts/presentation/profile_setup_page.dart';
import 'package:fee_app/features/auth/data/auth_api_client.dart';
import 'package:fee_app/features/auth/data/backend_auth_repository.dart';
import 'package:fee_app/features/auth/data/passkey_authenticator.dart';
import 'package:fee_app/features/auth/presentation/widgets/auth_card.dart';
import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:fee_app/features/footprint/data/local_scan_history_repository.dart';
import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:fee_app/features/footprint/domain/footprint_repository.dart';
import 'package:fee_app/features/footprint/presentation/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../data/fake_case_storage.dart';
import '../footprint/fake_scan_history_storage.dart';
import '../support/in_memory_token_storage.dart';
import '../support/scan_form_test_helpers.dart';

class _ForbiddenPasskey extends PasskeyAuthenticator {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Passkey must not be invoked');
}

class _IdentityRepository extends IdentityProfileRepository {
  IdentityProfile? profile;
  @override
  Future<IdentityProfile?> getProfile(String accountId) async => profile;
  @override
  Future<void> saveProfile(IdentityProfile profile) async =>
      this.profile = profile;
  @override
  Future<void> deleteProfile(String accountId) async => profile = null;
}

class _FootprintRepository implements FootprintRepository {
  String? scannedIdentity;
  String? scannedEmail;
  List<String>? scannedAliases;
  @override
  Future<FootprintProfile> getProfile() async =>
      FootprintProfile.initial(targetIdentity: '');
  @override
  Future<FootprintProfile> scanIdentity(
    String identity, {
    List<String> associatedUsernames = const [],
    String? associatedEmail,
    bool consentSelfAudit = true,
  }) async {
    scannedIdentity = identity;
    scannedEmail = associatedEmail;
    scannedAliases = associatedUsernames;
    return FootprintProfile.initial(targetIdentity: identity);
  }
}

class _Harness {
  final identity = _IdentityRepository();
  final footprint = _FootprintRepository();
  final paths = <String>[];
  Completer<void>? requestGate;
  bool unavailable = false;

  late final auth = BackendAuthRepository(
    testingAccessEnabled: true,
    authenticator: _ForbiddenPasskey(),
    apiClient: AuthApiClient(
      tokenStorage: InMemoryTokenStorage(),
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/testing/session')) {
          if (requestGate != null) await requestGate!.future;
          if (unavailable) return http.Response('{}', 503);
          return http.Response(
            '{"access_token":"guest-token","refresh_token":"guest-refresh"}',
            201,
          );
        }
        expect(request.url.path, '/api/v1/auth/me');
        return http.Response(
          jsonEncode({
            'id': 'guest-1',
            'label': 'Pruebas',
            'credentials_count': 0,
            'created_at': '2026-09-11T12:00:00Z',
          }),
          200,
        );
      }),
    ),
  );

  Widget get app => FeeApp(
    testingAccessEnabled: true,
    authRepository: auth,
    repository: LocalCaseRepository(storage: FakeCaseStorage()),
    identityProfileRepository: identity,
    footprintRepositoryFactory: (_) => footprint,
    scanHistoryRepositoryFactory: (_) =>
        LocalScanHistoryRepository(storage: FakeScanHistoryStorage()),
  );
}

void _expectNoLogin() {
  expect(find.byType(AuthCard), findsNothing);
  expect(find.byType(AccountPickerPage), findsNothing);
  expect(find.text('Entrar con llave de acceso'), findsNothing);
}

void main() {
  testWidgets(
    'startup opens input form automatically and submits only client data',
    (tester) async {
      final harness = _Harness()..requestGate = Completer<void>();
      await tester.pumpWidget(harness.app);
      await tester.pump();
      _expectNoLogin();
      expect(find.byKey(const Key('testing-access-loading')), findsOneWidget);
      harness.requestGate!.complete();
      await tester.pumpAndSettle();
      _expectNoLogin();
      expect(find.byType(ProfileSetupPage), findsOneWidget);
      expect(find.text('Pruebas'), findsNothing);
      final email = find.byKey(const Key('scan-identity-field'));
      expect(tester.widget<TextFormField>(email).initialValue, isEmpty);
      await tester.enterText(email, 'client@example.invalid');
      await fillScanContacts(
        tester,
        aliases: 'real_client',
        phone: '+52 55 1234 5678',
      );
      final submit = find.text('Guardar e Iniciar Auditoría');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(harness.footprint.scannedIdentity, '+525512345678');
      expect(harness.footprint.scannedEmail, 'client@example.invalid');
      expect(harness.footprint.scannedAliases, ['real_client']);
      expect(harness.identity.profile!.accountId, 'guest-1');
      expect(find.byType(DashboardPage), findsOneWidget);
      expect(harness.paths, [
        '/api/v1/auth/testing/session',
        '/api/v1/auth/me',
      ]);
      await tester.tap(find.byTooltip('Abrir perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Cerrar sesión'), findsNothing);
      _expectNoLogin();
    },
  );

  testWidgets(
    'failed automatic access offers accessible retry and retains form route',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      final harness = _Harness()..unavailable = true;
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();
      _expectNoLogin();
      expect(find.byKey(const Key('testing-access-error')), findsOneWidget);
      expect(find.byType(ProfileSetupPage), findsNothing);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
      harness.unavailable = false;
      await tester.ensureVisible(find.byKey(const Key('testing-access-retry')));
      await tester.tap(find.byKey(const Key('testing-access-retry')));
      await tester.pumpAndSettle();
      _expectNoLogin();
      expect(find.byType(ProfileSetupPage), findsOneWidget);
      expect(find.byKey(const Key('testing-access-error')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saved client opens dashboard in the same testing account', (
    tester,
  ) async {
    final harness = _Harness();
    harness.identity.profile = IdentityProfile(
      accountId: 'guest-1',
      mainIdentifier: 'client@example.invalid',
      associatedEmail: 'client@example.invalid',
      associatedUsernames: const ['real_client'],
      phone: '+525512345678',
      createdAt: DateTime.utc(2026, 9, 11),
    );
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    expect(find.byType(DashboardPage), findsOneWidget);
    _expectNoLogin();
    expect(harness.footprint.scannedIdentity, isNull);
  });
}
