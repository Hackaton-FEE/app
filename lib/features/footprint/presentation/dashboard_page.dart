import 'dart:async';

import 'package:flutter/material.dart';

import '../../accounts/domain/local_account.dart';
import '../../auth/data/backend_auth_repository.dart';
import '../../auth/presentation/widgets/active_sessions_dialog.dart';
import '../../auth/presentation/widgets/change_password_dialog.dart';
import '../../auth/presentation/widgets/scan_capabilities_dialog.dart';
import '../../guard_ai/presentation/guard_ai_controller.dart';
import '../../guard_ai/presentation/guard_ai_page.dart';
import '../../cases/presentation/cases_controller.dart';
import '../../cases/presentation/cases_page.dart';
import '../domain/footprint_item.dart';
import 'footprint_controller.dart';
import 'scan_history_controller.dart';
import 'widgets/dashboard_tour.dart';
import 'widgets/footprint_report_navigation.dart';
import 'widgets/dashboard_spotlight.dart';
import 'widgets/dashboard_status.dart';
import 'widgets/footprint_action_bar.dart';
import 'widgets/footprint_explorer.dart';
import 'widgets/profile_drawer.dart';
import 'widgets/exposure_gauge.dart';
import 'widgets/footprint_detail_sheet.dart';
import 'widgets/recommendation_card.dart';
import 'widgets/scan_bottom_sheet.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.footprintController,
    required this.casesController,
    required this.guardAiController,
    this.scanHistoryController,
    required this.account,
    required this.onManageAccounts,
    this.authRepository,
    super.key,
  });

  final FootprintController footprintController;
  final CasesController casesController;
  final GuardAiController guardAiController;
  final ScanHistoryController? scanHistoryController;
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
    widget.guardAiController
        .setContextProfile(widget.footprintController.profile);
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
      builder: (_) => ActiveSessionsDialog(
        authRepository: widget.authRepository!,
      ),
    );
  }

  void _openChangePasswordDialog() {
    if (widget.authRepository == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => ChangePasswordDialog(
        authRepository: widget.authRepository!,
        onPasswordChanged: widget.onManageAccounts,
      ),
    );
  }

  void _openCapabilitiesDialog() {
    if (widget.authRepository == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => ScanCapabilitiesDialog(
        authRepository: widget.authRepository!,
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
                const Text(
                  "Osisn't",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
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
              isDemo: widget.account.isDemo,
              onManageAccounts: widget.onManageAccounts,
              historyCount: widget.scanHistoryController?.count ?? 0,
              onViewHistory: widget.scanHistoryController != null
                  ? _openScanHistory
                  : null,
              caseCount: widget.casesController.state.cases.length,
              onViewCases: _openAllCases,
              onHelp: _openHelp,
              onViewSessions:
                  widget.authRepository != null && !widget.account.isDemo
                      ? _openSessionsDialog
                      : null,
              onChangePassword:
                  widget.authRepository != null && !widget.account.isDemo
                      ? _openChangePasswordDialog
                      : null,
              onViewCapabilities: widget.authRepository != null
                  ? _openCapabilitiesDialog
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
            body: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: CustomScrollView(
                    key: const Key('dashboard-scroll'),
                    controller: _scrollController,
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          8,
                          24,
                          FootprintActionBar.contentHeight(context) +
                              MediaQuery.viewPaddingOf(context).bottom +
                              32,
                        ),
                        sliver: SliverMainAxisGroup(
                          slivers: [
                            SliverToBoxAdapter(
                              child: RepaintBoundary(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _region(
                                      DashboardStatus(
                                        footprint: footprint,
                                        history: widget.scanHistoryController,
                                      ),
                                    ),
                                    if (_tourStep != null && _tourStep != 1)
                                      _tourPanel(),
                                    if (profile != null) ...[
                                      _region(
                                        ExposureGauge(
                                          key: _tourTargets[0],
                                          profile: profile,
                                        ),
                                        0,
                                      ),
                                      const SizedBox(height: 20),
                                      _region(
                                        RecommendationCard(
                                          casesController:
                                              widget.casesController,
                                          historyCount:
                                              widget
                                                  .scanHistoryController
                                                  ?.count ??
                                              0,
                                          onViewHistory:
                                              widget.scanHistoryController !=
                                                  null
                                              ? _openScanHistory
                                              : null,
                                          featuredItem: featuredItem,
                                          onGuardAi: _openGuardAi,
                                          onViewAllCases: _openAllCases,
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (_tourStep == 1)
                              SliverToBoxAdapter(child: _tourPanel()),
                            if (profile != null)
                              FootprintExplorer(
                                tourTargetKey: _tourTargets[1],
                                tourStep: _tourStep,
                                profile: profile,
                                visibleItems: footprint.visibleItems,
                                selectedCategory: footprint.selectedCategory,
                                onCategorySelected: footprint.setCategoryFilter,
                                onFindingSelected: _showFindingDetail,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
