import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/accounts/data/demo_account_repository.dart';
import 'package:fee_app/features/accounts/domain/local_account.dart';
import 'package:fee_app/features/accounts/presentation/accounts_controller.dart';
import 'package:fee_app/features/auth/data/backend_auth_repository.dart';
import 'package:fee_app/features/auth/domain/scan_capability.dart';
import 'package:fee_app/features/auth/domain/session_info.dart';
import 'package:fee_app/features/auth/domain/user_profile.dart';
import 'package:fee_app/features/auth/presentation/widgets/auth_card.dart';
import 'package:fee_app/features/auth/data/passkey_authenticator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  String? registeredEmail;
  String? registeredPassword;
  String? loggedInEmail;
  String? loggedInPassword;

  @override
  Future<bool> checkHealth() async => true;

  @override
  Future<UserProfile> registerWithPasskey({
    String label = 'Mi Bóveda FEE',
    PasskeyAuthenticator? authenticator,
  }) async {
    registeredEmail = label;
    return UserProfile(
      id: 'test-uuid-passkey-registered',
      label: label,
      email: label,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<UserProfile> loginWithPasskey({
    PasskeyAuthenticator? authenticator,
  }) async {
    loggedInEmail = 'passkey-user';
    return UserProfile(
      id: 'test-uuid-passkey-loggedin',
      label: 'Passkey User',
      email: 'passkey-user@fee.local',
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<UserProfile> register({
    required String email,
    required String password,
  }) async {
    registeredEmail = email;
    registeredPassword = password;
    return UserProfile(
      id: 'test-uuid-registered',
      label: email,
      email: email,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    loggedInEmail = email;
    loggedInPassword = password;
    return UserProfile(
      id: 'test-uuid-loggedin',
      label: email,
      email: email,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<UserProfile?> restoreSession() async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<UserProfile> getProfile() async => UserProfile(
        id: 'test-uuid',
        email: 'user@example.com',
        isActive: true,
        createdAt: DateTime.now(),
      );

  @override
  Future<List<SessionInfo>> getSessions() async => [];

  @override
  Future<void> revokeSession(String sessionId) async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<List<ScanCapabilityProvider>> getScanCapabilities() async => [];
}

void main() {
  late FakeAuthRepository fakeAuth;
  late AccountsController controller;

  setUp(() {
    fakeAuth = FakeAuthRepository();
    controller = AccountsController(
      DemoAccountRepository(initialAccounts: [
        const LocalAccount(
          id: 'demo-1',
          name: 'Demo',
          email: 'demo@example.com',
          isDemo: true,
        )
      ]),
      authRepository: fakeAuth,
    );
  });

  tearDown(() => controller.dispose());

  Future<void> pumpAuthCard(WidgetTester tester) async {
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AuthCard(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders login form by default and can switch to register', (
    tester,
  ) async {
    await pumpAuthCard(tester);

    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
    expect(find.byKey(const Key('auth-password-field')), findsOneWidget);
    expect(find.byKey(const Key('auth-login-button')), findsOneWidget);
    expect(find.byKey(const Key('auth-register-email-field')), findsNothing);

    // Switch to register tab
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-register-email-field')), findsOneWidget);
    expect(find.byKey(const Key('auth-register-password-field')), findsOneWidget);
    expect(
      find.byKey(const Key('auth-register-confirm-password-field')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('auth-register-button')), findsOneWidget);
    expect(find.text('Mínimo 12 caracteres (12–128)'), findsOneWidget);
  });

  testWidgets('register form validates password length >= 12', (tester) async {
    await pumpAuthCard(tester);
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('auth-register-email-field')),
      'usuario@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-register-password-field')),
      'corta',
    );
    await tester.enterText(
      find.byKey(const Key('auth-register-confirm-password-field')),
      'corta',
    );

    await tester.tap(find.byKey(const Key('auth-register-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('La contraseña debe tener entre 12 y 128 caracteres.'),
      findsOneWidget,
    );
    expect(fakeAuth.registeredEmail, isNull);
  });

  testWidgets('register form validates username min length >= 2', (tester) async {
    await pumpAuthCard(tester);
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('auth-register-email-field')),
      'a',
    );
    await tester.enterText(
      find.byKey(const Key('auth-register-password-field')),
      'password-larga-1234',
    );
    await tester.enterText(
      find.byKey(const Key('auth-register-confirm-password-field')),
      'password-larga-1234',
    );

    await tester.tap(find.byKey(const Key('auth-register-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('El nombre debe tener al menos 2 caracteres.'),
      findsOneWidget,
    );
    expect(fakeAuth.registeredEmail, isNull);
  });

  testWidgets('register form accepts name/username without email format', (
    tester,
  ) async {
    await pumpAuthCard(tester);
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('auth-register-email-field')),
      'Carlos Ruiz',
    );
    await tester.enterText(
      find.byKey(const Key('auth-register-password-field')),
      'password-larga-1234',
    );
    await tester.enterText(
      find.byKey(const Key('auth-register-confirm-password-field')),
      'password-larga-1234',
    );

    await tester.tap(find.byKey(const Key('auth-register-button')));
    await tester.pumpAndSettle();

    expect(fakeAuth.registeredEmail, 'Carlos Ruiz');
    expect(fakeAuth.registeredPassword, 'password-larga-1234');
    expect(controller.activeAccount?.name, 'Carlos Ruiz');
  });

  testWidgets('login submits username credentials and signs in', (tester) async {
    await pumpAuthCard(tester);

    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'Carlos Ruiz',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'password-larga-1234',
    );

    await tester.tap(find.byKey(const Key('auth-login-button')));
    await tester.pumpAndSettle();

    expect(fakeAuth.loggedInEmail, 'Carlos Ruiz');
    expect(fakeAuth.loggedInPassword, 'password-larga-1234');
    expect(controller.activeAccount?.name, 'Carlos Ruiz');
  });
}
