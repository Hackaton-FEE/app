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
        if (request.url.path.endsWith('/token/refresh')) {
          return http.Response(
            '{"access_token":"renewed-token","refresh_token":"renewed-refresh"}',
            200,
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

void _expectWelcome() {
  expect(find.byType(AuthCard), findsOneWidget);
  expect(find.byType(AccountPickerPage), findsOneWidget);
  expect(find.byKey(const Key('auth-passkey-login-button')), findsOneWidget);
  expect(find.text('Entrar'), findsOneWidget);
  expect(find.text('Crear cuenta'), findsNothing);
  expect(find.text('Entrar con llave de acceso'), findsNothing);
  expect(find.byKey(const Key('auth-label-field')), findsNothing);
}

Future<void> _enter(WidgetTester tester, {bool settle = true}) async {
  final button = find.byKey(const Key('auth-passkey-login-button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'welcome, entry progress, client form, logout and reentry preserve account',
    (tester) async {
      final harness = _Harness()..requestGate = Completer<void>();
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();
      _expectWelcome();
      expect(harness.paths, isEmpty);
      await _enter(tester, settle: false);
      expect(find.byType(AccountPickerPage), findsOneWidget);
      expect(find.text('Preparando acceso…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('auth-passkey-login-button')),
            )
            .onPressed,
        isNull,
      );
      harness.requestGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileSetupPage), findsOneWidget);
      expect(find.byType(AccountPickerPage), findsNothing);
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
      final saved = harness.identity.profile;
      expect(saved!.accountId, 'guest-1');
      expect(find.byType(DashboardPage), findsOneWidget);
      expect(harness.paths, [
        '/api/v1/auth/testing/session',
        '/api/v1/auth/me',
      ]);
      await tester.tap(find.byTooltip('Abrir perfil'));
      await tester.pumpAndSettle();
      final logout = find.text('Cerrar sesión');
      await tester.ensureVisible(logout);
      await tester.tap(logout);
      await tester.pumpAndSettle();
      _expectWelcome();
      expect(harness.identity.profile, same(saved));
      expect(harness.auth.tokenStorage.accessToken, isNull);
      expect(
        await harness.auth.tokenStorage.readRefreshToken(),
        'guest-refresh',
      );
      expect(harness.paths.length, 2);
      await _enter(tester);
      expect(find.byType(DashboardPage), findsOneWidget);
      expect(harness.identity.profile, same(saved));
      expect(harness.paths, [
        '/api/v1/auth/testing/session',
        '/api/v1/auth/me',
        '/api/v1/auth/token/refresh',
        '/api/v1/auth/me',
      ]);
    },
  );

  testWidgets('failed entry preserves welcome with accessible retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = _Harness()..unavailable = true;
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    _expectWelcome();
    await _enter(tester);
    _expectWelcome();
    expect(
      find.text('No se pudo completar la consulta al servidor.'),
      findsOneWidget,
    );
    expect(find.byType(ProfileSetupPage), findsNothing);
    final semantics = tester.ensureSemantics();
    await tester.ensureVisible(
      find.byKey(const Key('auth-passkey-login-button')),
    );
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
    expect(tester.takeException(), isNull);
    harness.unavailable = false;
    await _enter(tester);
    expect(find.byType(ProfileSetupPage), findsOneWidget);
    expect(find.byType(AccountPickerPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cold start preserves welcome until click even with an existing session',
    (tester) async {
      final harness = _Harness();
      harness.identity.profile = IdentityProfile(
        accountId: 'guest-1',
        mainIdentifier: 'client@example.invalid',
        associatedEmail: 'client@example.invalid',
        associatedUsernames: const ['real_client'],
        phone: '+525512345678',
        createdAt: DateTime.utc(2026, 9, 11),
      );
      await harness.auth.startTestingSession();
      harness.paths.clear();
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();
      _expectWelcome();
      expect(harness.paths, isEmpty);
      await _enter(tester);
      expect(find.byType(DashboardPage), findsOneWidget);
      expect(harness.paths, ['/api/v1/auth/me']);
      expect(harness.footprint.scannedIdentity, isNull);
    },
  );
}
