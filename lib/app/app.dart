import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/accounts/data/demo_account_repository.dart';
import '../features/accounts/domain/account_repository.dart';
import '../features/accounts/domain/local_account.dart';
import '../features/accounts/presentation/account_picker_page.dart';
import '../features/accounts/presentation/accounts_controller.dart';
import '../features/cases/data/flutter_secure_case_storage.dart';
import '../features/cases/data/local_case_repository.dart';
import '../features/cases/domain/case_repository.dart';
import '../features/cases/presentation/cases_controller.dart';
import '../features/cases/presentation/cases_page.dart';
import '../features/footprint/data/flutter_secure_scan_storage.dart';
import '../features/footprint/data/local_scan_history_repository.dart';
import '../features/footprint/data/mock_footprint_repository.dart';
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
    this.showCasesAsHome = false,
    super.key,
  });

  final CaseRepository? repository;
  final FootprintRepository Function(LocalAccount account)?
  footprintRepositoryFactory;
  final ScanHistoryRepository Function(LocalAccount account)?
  scanHistoryRepositoryFactory;
  final AccountRepository? accountRepository;
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
    _accounts = AccountsController(
      widget.accountRepository ?? DemoAccountRepository(),
    );
    unawaited(_cases.load());
    if (!widget.showCasesAsHome) unawaited(_accounts.load());
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
        return _AccountSession(
          footprint: FootprintController(
            widget.footprintRepositoryFactory?.call(account) ??
                MockFootprintRepository(targetIdentity: account.email),
            onScanCompleted: history.recordScan,
          ),
          guardAi: GuardAiController(DemoGuardAiRepository()),
          scanHistory: history,
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
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: "Osisn't · Tu huella digital",
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
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
              return DashboardPage(
                key: ValueKey(account.id),
                footprintController: session.footprint,
                casesController: _cases,
                guardAiController: session.guardAi,
                scanHistoryController: session.scanHistory,
                account: account,
                onManageAccounts: _accounts.signOut,
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
  });
  final FootprintController footprint;
  final GuardAiController guardAi;
  final ScanHistoryController scanHistory;
}
