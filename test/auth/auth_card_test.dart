import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/accounts/presentation/accounts_controller.dart';
import 'package:fee_app/features/auth/data/auth_api_client.dart';
import 'package:fee_app/features/auth/data/backend_auth_repository.dart';
import 'package:fee_app/features/auth/data/passkey_authenticator.dart';
import 'package:fee_app/features/auth/domain/user_profile.dart';
import 'package:fee_app/features/auth/presentation/widgets/auth_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth implements AuthRepository {
  String? registeredLabel;
  int logins = 0;
  bool failLogin = false;

  UserProfile _profile(String label) => UserProfile(
    id: 'test-account',
    label: label,
    createdAt: DateTime.utc(2026, 9, 10),
  );

  @override
  Future<UserProfile> registerWithPasskey({
    String label = 'Mi Bóveda FEE',
    PasskeyAuthenticator? authenticator,
  }) async {
    registeredLabel = label;
    return _profile(label);
  }

  @override
  Future<UserProfile> loginWithPasskey({
    PasskeyAuthenticator? authenticator,
  }) async {
    logins++;
    if (failLogin) {
      throw const AuthApiException(
        message: 'No se encontró una llave de acceso.',
        code: 'no_passkey_found',
      );
    }
    return _profile('Cuenta de prueba');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Auth auth;
  late AccountsController controller;
  setUp(() {
    auth = _Auth();
    controller = AccountsController(null, authRepository: auth);
  });
  tearDown(() => controller.dispose());

  Future<void> start(WidgetTester tester, {bool compact = false}) async {
    await controller.load();
    if (compact) {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(compact ? 2 : 1)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: AuthCard(controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final button = find.byKey(Key(key));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'only native passkey login is offered and opens the returned account',
    (tester) async {
      await start(tester);
      expect(find.byType(TextField), findsNothing);
      await tap(tester, 'auth-passkey-login-button');
      expect(auth.logins, 1);
      expect(controller.activeAccount?.id, 'test-account');
      expect(auth.registeredLabel, isNull);
    },
  );

  testWidgets('failed login never creates a replacement account', (
    tester,
  ) async {
    auth.failLogin = true;
    await start(tester);
    await tap(tester, 'auth-passkey-login-button');
    expect(controller.activeAccount, isNull);
    expect(auth.registeredLabel, isNull);
    expect(find.text('No se encontró una llave de acceso.'), findsOneWidget);
  });

  testWidgets(
    'registration validates label and requires an explicit registration action',
    (tester) async {
      await start(tester);
      await tap(tester, 'auth-mode-button');
      await tap(tester, 'auth-passkey-register-button');
      expect(auth.registeredLabel, isNull);
      expect(
        find.text('Escribe un nombre para reconocer esta cuenta.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('auth-label-field')),
        'Mi cuenta',
      );
      await tap(tester, 'auth-passkey-register-button');
      expect(auth.registeredLabel, 'Mi cuenta');
      expect(auth.logins, 0);
      expect(controller.activeAccount?.name, 'Mi cuenta');
    },
  );

  testWidgets(
    'login and registration remain reachable at 320px and 200% text',
    (tester) async {
      await start(tester, compact: true);
      await tap(tester, 'auth-mode-button');
      await tester.ensureVisible(find.byKey(const Key('auth-label-field')));
      await tester.enterText(
        find.byKey(const Key('auth-label-field')),
        'Prueba',
      );
      await tap(tester, 'auth-passkey-register-button');
      expect(auth.registeredLabel, 'Prueba');
      expect(tester.takeException(), isNull);
    },
  );
}
