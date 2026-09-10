import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/app_logo.dart';
import '../../accounts/domain/local_account.dart';
import '../../accounts/presentation/identity_profile_controller.dart';
import '../../accounts/presentation/profile_setup_page.dart';
import '../../auth/data/backend_auth_repository.dart';
import '../../auth/presentation/widgets/active_sessions_dialog.dart';
import '../../auth/presentation/widgets/scan_capabilities_dialog.dart';
import '../../guard_ai/presentation/guard_ai_controller.dart';
import '../../guard_ai/presentation/guard_ai_page.dart';
import '../../cases/presentation/cases_controller.dart';
import '../../cases/presentation/cases_page.dart';
import '../domain/footprint_item.dart';
import 'footprint_controller.dart';
import 'scan_history_controller.dart';
import 'widgets/dashboard_tour.dart';
import 'widgets/dashboard_content.dart';
import 'widgets/footprint_report_navigation.dart';
import 'widgets/dashboard_spotlight.dart';
import 'widgets/footprint_action_bar.dart';
import 'widgets/profile_drawer.dart';
import 'widgets/footprint_detail_sheet.dart';
import 'widgets/scan_bottom_sheet.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.footprintController,
    required this.casesController,
    required this.guardAiController,
    this.scanHistoryController,
    this.identityController,
    required this.account,
    required this.onManageAccounts,
    this.authRepository,
    super.key,
  });

  final FootprintController footprintController;
  final CasesController casesController;
  final GuardAiController guardAiController;
  final ScanHistoryController? scanHistoryController;
  final IdentityProfileController? identityController;
  final LocalAccount account;
  final VoidCallback onManageAccounts;
  final AuthRepository? authRepository;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _scrollController = ScrollController();
  final _tourAnchor = GlobalKey();
  final _spotlightSurface = GlobalKey();
  final _tourTargets = List.generate(5, (_) => GlobalKey());
  bool _drawerOpen = false;
  final _helpFocus = FocusNode();
  final _tourFocus = FocusNode();
  int? _tourStep;

  void _setTourStep(int? step) {
    setState(() => _tourStep = step);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (step == null) {
        _helpFocus.requestFocus();
      } else if (_tourAnchor.currentContext case final target?) {
        _tourFocus.requestFocus();
        Scrollable.ensureVisible(
          target,
          alignment: 0.05,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
        );
      }
    });
  }

  Widget _region(Widget child, [int step = -1]) => SpotlightRegion(
    dimmed: _tourStep != null && _tourStep != step && !_drawerOpen,
    child: child,
  );

  Widget _tourPanel() => DashboardTourPanel(
    key: _tourAnchor,
    step: _tourStep!,
    focusNode: _tourFocus,
    onStep: _setTourStep,
  );
  @override
  void dispose() {
    _scrollController.dispose();
    _helpFocus.dispose();
    _tourFocus.dispose();
    super.dispose();
  }

  void _openHelp() => _setTourStep(0);
  @override
  void initState() {
    super.initState();
    if (widget.footprintController.profile == null &&
        !widget.footprintController.isLoading) {
      unawaited(widget.footprintController.loadProfile());
    }
    if (widget.scanHistoryController?.error == null) {
      unawaited(widget.scanHistoryController?.load());
    }
  }

  void _openScanSheet() {
    if (widget.footprintController.isLoading) return;
    final currentTarget =
        widget.footprintController.profile?.targetIdentity ??
        widget.account.email;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      backgroundColor: Colors.transparent,
      builder: (_) => ScanBottomSheet(
        initialIdentity: currentTarget,
        onScan: (identity) {
          unawaited(widget.footprintController.scanIdentity(identity));
        },
      ),
    );
  }

  Future<void> _openNewReport(FootprintItem item) =>
      openFootprintReport(context, widget.casesController, item);

  void _openGuardAi() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GuardAiPage(
          controller: widget.guardAiController,
          casesController: widget.casesController,
        ),
      ),
    );
  }

  void _openAllCases() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => CasesPage(controller: widget.casesController),
    ),
  );

  void _openScanHistory() => openScanHistory(
    context,
    widget.scanHistoryController,
    widget.footprintController,
    _openScanSheet,
  );

  void _openSessionsDialog() {
    if (widget.authRepository == null) return;
    showDialog<void>(
      context: context,
      builder: (_) =>
          ActiveSessionsDialog(authRepository: widget.authRepository!),
    );
  }

  void _openCapabilitiesDialog() {
    if (widget.authRepository == null) return;
    showDialog<void>(
      context: context,
      builder: (_) =>
          ScanCapabilitiesDialog(authRepository: widget.authRepository!),
    );
  }

  void _openIdentitySetup() {
    if (widget.identityController == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProfileSetupPage(
          account: widget.account,
          identityController: widget.identityController!,
          footprintController: widget.footprintController,
          isInitialOnboarding: false,
        ),
      ),
    );
  }

  void _showFindingDetail(FootprintItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          FootprintDetailSheet(item: item, onCreateReport: _openNewReport),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.footprintController,
        widget.casesController,
        if (widget.scanHistoryController != null) widget.scanHistoryController!,
      ]),
      builder: (context, _) {
        final footprint = widget.footprintController;
        final profile = footprint.profile;
        final featuredItem = profile == null || profile.items.isEmpty
            ? null
            : profile.items.firstWhere(
                (item) => item.riskLevel == FootprintRisk.high,
                orElse: () => profile.items.first,
              );
        return DashboardSpotlight(
          surfaceKey: _spotlightSurface,
          panelKey: _tourAnchor,
          targetKey: _tourTargets[_tourStep ?? 0],
          scrollController: _scrollController,
          enabled: _tourStep != null && !_drawerOpen,
          targetInBody: (_tourStep ?? 0) < 2,
          bottomInset:
              FootprintActionBar.contentHeight(context) +
              MediaQuery.viewPaddingOf(context).bottom,
          child: Scaffold(
            onDrawerChanged: (open) => setState(() => _drawerOpen = open),
            extendBody: _tourStep == null,
            appBar: AppBar(
              toolbarHeight: 72,
              title: _region(
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppLogo(size: 24),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "Osisn't",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              leading: Builder(
                key: _tourTargets[4],
                builder: (context) => _region(
                  IconButton(
                    key: const Key('dashboard-profile-button'),
                    tooltip: 'Abrir perfil',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: Icon(
                      _tourStep == 4 ? Icons.person_pin : Icons.menu_rounded,
                    ),
                  ),
                  4,
                ),
              ),
              actions: [
                _region(
                  IconButton(
                    focusNode: _helpFocus,
                    tooltip: 'Ayuda de uso',
                    onPressed: _openHelp,
                    icon: const Icon(Icons.help_outline),
                  ),
                ),
              ],
            ),
            drawer: ProfileDrawer(
              identity: widget.account.email,
              accountName: widget.account.name,
              onManageAccounts: widget.onManageAccounts,
              historyCount: widget.scanHistoryController?.count ?? 0,
              onViewHistory: widget.scanHistoryController != null
                  ? _openScanHistory
                  : null,
              caseCount: widget.casesController.state.cases.length,
              onViewCases: _openAllCases,
              onHelp: _openHelp,
              onViewSessions: widget.authRepository != null
                  ? _openSessionsDialog
                  : null,
              onViewCapabilities: widget.authRepository != null
                  ? _openCapabilitiesDialog
                  : null,
              onViewIdentity: widget.identityController != null
                  ? _openIdentitySetup
                  : null,
            ),
            bottomNavigationBar: FootprintActionBar(
              scanning: footprint.isLoading,
              tourStep: _tourStep,
              scanKey: _tourTargets[2],
              guardAiKey: _tourTargets[3],
              onScan: _openScanSheet,
              onGuardAi: _openGuardAi,
            ),
            body: DashboardContent(
              footprint: footprint,
              casesController: widget.casesController,
              history: widget.scanHistoryController,
              featuredItem: featuredItem,
              scrollController: _scrollController,
              region: (child, step) => _region(child, step),
              tourStep: _tourStep,
              tourPanel: _tourStep == null ? null : _tourPanel(),
              tourTargets: _tourTargets,
              onViewHistory: _openScanHistory,
              onGuardAi: _openGuardAi,
              onViewAllCases: _openAllCases,
              onFindingSelected: _showFindingDetail,
            ),
          ),
        );
      },
    );
  }
}
