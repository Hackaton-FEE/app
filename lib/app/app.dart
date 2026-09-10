import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/accounts/data/demo_account_repository.dart';
import '../features/accounts/data/flutter_secure_identity_storage.dart';
import '../features/accounts/data/local_identity_profile_repository.dart';
import '../features/accounts/domain/account_repository.dart';
import '../features/accounts/domain/identity_profile_repository.dart';
import '../features/accounts/domain/local_account.dart';
import '../features/accounts/presentation/account_picker_page.dart';
import '../features/accounts/presentation/accounts_controller.dart';
import '../features/accounts/presentation/identity_profile_controller.dart';
import '../features/accounts/presentation/profile_setup_page.dart';
import '../features/auth/data/backend_auth_repository.dart';
import '../features/cases/data/flutter_secure_case_storage.dart';
import '../features/cases/data/local_case_repository.dart';
import '../features/cases/domain/case_repository.dart';
import '../features/cases/presentation/cases_controller.dart';
import '../features/cases/presentation/cases_page.dart';
import '../features/footprint/data/backend_footprint_repository.dart';
import '../features/footprint/data/flutter_secure_scan_storage.dart';
import '../features/footprint/data/local_scan_history_repository.dart';
import '../features/footprint/data/mock_footprint_repository.dart';
import '../features/footprint/data/osint_client.dart';
import '../features/footprint/domain/footprint_repository.dart';
import '../features/footprint/domain/scan_history_repository.dart';
import '../features/footprint/presentation/dashboard_page.dart';
import '../features/footprint/presentation/footprint_controller.dart';
import '../features/footprint/presentation/scan_history_controller.dart';
import '../features/guard_ai/data/demo_guard_ai_repository.dart';
import '../features/guard_ai/presentation/guard_ai_controller.dart';
import 'theme.dart';

class FeeApp extends StatefulWidget {
  const FeeApp({
    this.repository,
    this.footprintRepositoryFactory,
    this.scanHistoryRepositoryFactory,
    this.accountRepository,
    this.authRepository,
    this.identityProfileRepository,
    this.showCasesAsHome = false,
    super.key,
  });

  final CaseRepository? repository;
  final FootprintRepository Function(LocalAccount account)?
  footprintRepositoryFactory;
  final ScanHistoryRepository Function(LocalAccount account)?
  scanHistoryRepositoryFactory;
  final AccountRepository? accountRepository;
  final AuthRepository? authRepository;
  final IdentityProfileRepository? identityProfileRepository;
  final bool showCasesAsHome;

  @override
  State<FeeApp> createState() => _FeeAppState();
}

class _FeeAppState extends State<FeeApp> {
  late final CasesController _cases;
  late final AccountsController _accounts;
  final _sessions = <String, _AccountSession>{};

  @override
  void initState() {
    super.initState();
    _cases = CasesController(
      widget.repository ??
          LocalCaseRepository(storage: FlutterSecureCaseStorage()),
    );
    final authRepo = widget.authRepository ??
        (widget.accountRepository == null ? BackendAuthRepository() : null);
    _accounts = AccountsController(
      widget.accountRepository ?? DemoAccountRepository(),
      authRepository: authRepo,
    );
    unawaited(_cases.load());
    if (!widget.showCasesAsHome) {
      unawaited(_accounts.load());
      if (authRepo != null) {
        unawaited(_accounts.restoreSession());
      }
    }
  }

  _AccountSession _sessionFor(LocalAccount account) =>
      _sessions.putIfAbsent(account.id, () {
        final scanHistoryRepo =
            widget.scanHistoryRepositoryFactory?.call(account) ??
            LocalScanHistoryRepository(
              storage: FlutterSecureScanStorage(
                prefix: 'fee.scan.${account.id}.v1.',
              ),
            );
        final history = ScanHistoryController(scanHistoryRepo);

        final identityRepo = widget.identityProfileRepository ??
            LocalIdentityProfileRepository(
              storage: FlutterSecureIdentityStorage(
                prefix: 'fee.identity.${account.id}.v1.',
              ),
            );
        final identity = IdentityProfileController(
          identityRepo,
          accountId: account.id,
          isDemo: account.isDemo,
        );
        unawaited(identity.load());

        FootprintController? footprintController;
        FootprintRepository footprintRepo;

        if (widget.footprintRepositoryFactory != null) {
          footprintRepo = widget.footprintRepositoryFactory!(account);
        } else if (!account.isDemo &&
            _accounts.authRepository is BackendAuthRepository) {
          final backendAuth = _accounts.authRepository! as BackendAuthRepository;
          final token = backendAuth.tokenStorage.accessToken ?? '';
          footprintRepo = BackendFootprintRepository(
            client: OsintClient(accessToken: token),
            targetIdentity: account.email,
            fallbackRepository:
                MockFootprintRepository(targetIdentity: account.email),
            onProgressUpdate: (stage, _) {
              footprintController?.updateStage(stage);
            },
          );
        } else {
          footprintRepo =
              MockFootprintRepository(targetIdentity: account.email);
        }

        final footprint = FootprintController(
          footprintRepo,
          onScanCompleted: history.recordScan,
        );
        footprintController = footprint;

        return _AccountSession(
          footprint: footprint,
          guardAi: GuardAiController(DemoGuardAiRepository()),
          scanHistory: history,
          identity: identity,
        );
      });

  @override
  void dispose() {
    _cases.dispose();
    _accounts.dispose();
    for (final session in _sessions.values) {
      session.footprint.dispose();
      session.guardAi.dispose();
      session.scanHistory.dispose();
      session.identity.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: "Osisn't · Tu huella digital",
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    darkTheme: buildAppDarkTheme(),
    themeMode: ThemeMode.system,
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: widget.showCasesAsHome
        ? CasesPage(controller: _cases)
        : ListenableBuilder(
            listenable: _accounts,
            builder: (context, _) {
              final account = _accounts.activeAccount;
              if (account == null) {
                return AccountPickerPage(controller: _accounts);
              }
              final session = _sessionFor(account);
              return ListenableBuilder(
                listenable: session.identity,
                builder: (context, _) {
                  if (session.identity.needsOnboarding) {
                    return ProfileSetupPage(
                      account: account,
                      identityController: session.identity,
                      footprintController: session.footprint,
                      isInitialOnboarding: true,
                    );
                  }
                  return DashboardPage(
                    key: ValueKey(account.id),
                    footprintController: session.footprint,
                    casesController: _cases,
                    guardAiController: session.guardAi,
                    scanHistoryController: session.scanHistory,
                    identityController: session.identity,
                    account: account,
                    onManageAccounts: _accounts.signOut,
                    authRepository: _accounts.authRepository,
                  );
                },
              );
            },
          ),
  );
}

class _AccountSession {
  const _AccountSession({
    required this.footprint,
    required this.guardAi,
    required this.scanHistory,
    required this.identity,
  });
  final FootprintController footprint;
  final GuardAiController guardAi;
  final ScanHistoryController scanHistory;
  final IdentityProfileController identity;
}
