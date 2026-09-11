import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
import '../features/footprint/data/unavailable_footprint_repository.dart';
import '../features/footprint/data/osint_client.dart';
import '../features/footprint/data/pending_scan_store.dart';
import '../features/footprint/domain/footprint_repository.dart';
import '../features/footprint/domain/scan_history_repository.dart';
import '../features/footprint/presentation/dashboard_page.dart';
import '../features/footprint/presentation/footprint_controller.dart';
import '../features/footprint/presentation/scan_history_controller.dart';
import '../features/guard_ai/data/assistant_client.dart';
import '../features/guard_ai/data/backend_guard_ai_repository.dart';
import '../features/guard_ai/data/unavailable_guard_ai_repository.dart';
import '../features/guard_ai/domain/guard_ai_repository.dart';
import '../features/guard_ai/presentation/guard_ai_controller.dart';
import 'access_loading_gate.dart';
import 'theme.dart';

class FeeApp extends StatefulWidget {
  const FeeApp({
    this.repository,
    this.footprintRepositoryFactory,
    this.scanHistoryRepositoryFactory,
    this.guardAiRepositoryFactory,
    this.accountRepository,
    this.authRepository,
    this.identityProfileRepository,
    this.showCasesAsHome = false,
    this.testingAccessEnabled = false,
    super.key,
  });

  final CaseRepository? repository;
  final FootprintRepository Function(LocalAccount account)?
  footprintRepositoryFactory;
  final ScanHistoryRepository Function(LocalAccount account)?
  scanHistoryRepositoryFactory;
  final GuardAiRepository Function(LocalAccount account)?
  guardAiRepositoryFactory;
  final AccountRepository? accountRepository;
  final AuthRepository? authRepository;
  final IdentityProfileRepository? identityProfileRepository;
  final bool showCasesAsHome;
  final bool testingAccessEnabled;

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
    final authRepo =
        widget.authRepository ??
        (widget.accountRepository == null
            ? BackendAuthRepository(
                testingAccessEnabled: widget.testingAccessEnabled,
              )
            : null);
    _accounts = AccountsController(
      widget.accountRepository,
      authRepository: authRepo,
    );
    unawaited(_cases.load());
    if (!widget.showCasesAsHome) {
      unawaited(_loadAccounts(authRepo));
    }
  }

  Future<void> _loadAccounts(AuthRepository? authRepo) async {
    await _accounts.load();
    if (mounted && authRepo != null && !widget.testingAccessEnabled) {
      await _accounts.restoreSession();
    }
  }

  /// Una instancia nueva por llamada: cada chat de GuardAI guarda su propio
  /// historial en memoria (el servidor no persiste la conversación).
  GuardAiRepository _guardAiRepositoryFor(
    LocalAccount account,
    FootprintController footprint,
  ) {
    if (widget.guardAiRepositoryFactory != null) {
      return widget.guardAiRepositoryFactory!(account);
    }
    if (_accounts.authRepository is BackendAuthRepository) {
      final backendAuth = _accounts.authRepository! as BackendAuthRepository;
      return BackendGuardAiRepository(
        currentProfile: () => footprint.profile,
        client: AssistantClient(
          tokenProvider: () => backendAuth.accessToken,
          asyncTokenProvider: ({forceRefresh = false}) =>
              backendAuth.ensureAccessToken(forceRefresh: forceRefresh),
        ),
      );
    }
    return const UnavailableGuardAiRepository();
  }

  _AccountSession _sessionFor(LocalAccount account) => _sessions.putIfAbsent(
    account.id,
    () {
      final scanHistoryRepo =
          widget.scanHistoryRepositoryFactory?.call(account) ??
          LocalScanHistoryRepository(
            storage: FlutterSecureScanStorage(
              prefix: 'fee.scan.${account.id}.v1.',
            ),
          );
      final history = ScanHistoryController(scanHistoryRepo);

      final identityRepo =
          widget.identityProfileRepository ??
          LocalIdentityProfileRepository(
            storage: FlutterSecureIdentityStorage(
              prefix: 'fee.identity.${account.id}.v1.',
            ),
          );
      final identity = IdentityProfileController(
        identityRepo,
        accountId: account.id,
      );
      unawaited(identity.load());

      FootprintController? footprintController;
      FootprintRepository footprintRepo;

      if (widget.footprintRepositoryFactory != null) {
        footprintRepo = widget.footprintRepositoryFactory!(account);
      } else if (_accounts.authRepository is BackendAuthRepository) {
        final backendAuth = _accounts.authRepository! as BackendAuthRepository;
        footprintRepo = BackendFootprintRepository(
          client: OsintClient(
            tokenProvider: () => backendAuth.accessToken,
            asyncTokenProvider: ({forceRefresh = false}) =>
                backendAuth.ensureAccessToken(forceRefresh: forceRefresh),
          ),
          pendingStore: PendingScanStore(
            FlutterSecureScanStorage(prefix: 'fee.pending.${account.id}.v1.'),
          ),
          targetIdentity: account.email,
          historyRepository: scanHistoryRepo,
          onProgressUpdate: (stage, _) {
            footprintController?.updateStage(stage);
          },
        );
      } else {
        footprintRepo = UnavailableFootprintRepository(
          targetIdentity: account.email,
        );
      }

      final footprint = FootprintController(
        footprintRepo,
        onScanCompleted: (profile) async {
          await history.recordScan(profile);
          if (history.error != null) {
            throw const FormatException(
              'No se pudo guardar el análisis. Reintenta para conservarlo.',
            );
          }
        },
      );
      footprintController = footprint;

      return _AccountSession(
        footprint: footprint,
        guardAi: GuardAiController(
          _guardAiRepositoryFor(account, footprint),
          createRepository: () => _guardAiRepositoryFor(account, footprint),
        ),
        scanHistory: history,
        identity: identity,
      );
    },
  );

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
                  if (session.identity.error != null ||
                      !session.identity.isLoaded ||
                      session.identity.isLoading) {
                    return AccessLoadingGate(
                      error: session.identity.error,
                      onRetry: session.identity.load,
                      onSignOut: _accounts.signOut,
                    );
                  }
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
