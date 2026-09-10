import 'dart:async';

import 'package:flutter/material.dart';

import '../../accounts/domain/local_account.dart';
import '../../guard_ai/presentation/guard_ai_controller.dart';
import '../../guard_ai/presentation/guard_ai_page.dart';
import '../../cases/presentation/case_details_page.dart';
import '../../cases/presentation/case_form_page.dart';
import '../../cases/presentation/cases_controller.dart';
import '../../cases/presentation/cases_page.dart';
import '../domain/footprint_item.dart';
import 'footprint_controller.dart';
import 'widgets/dashboard_tour.dart';
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
    required this.account,
    required this.onManageAccounts,
    super.key,
  });

  final FootprintController footprintController;
  final CasesController casesController;
  final GuardAiController guardAiController;
  final LocalAccount account;
  final VoidCallback onManageAccounts;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _scrollController = ScrollController();
  final _tourAnchor = GlobalKey();
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
  }

  void _openScanSheet() {
    if (widget.footprintController.isLoading) return;
    final currentTarget =
        widget.footprintController.profile?.targetIdentity ??
        'usuario@ejemplo.com';

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

  Future<void> _openNewReport(FootprintItem sourceItem) async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CaseFormPage(
          controller: widget.casesController,
          initialTitle: 'Retiro de datos: ${sourceItem.platform}',
          initialSourceUrl: sourceItem.sourceUrl,
          initialCategory: sourceItem.suggestedCaseCategory,
          initialNotes:
              'Origen: Hallazgo de demostración de Huella Digital\n${sourceItem.description}\n\nDatos expuestos: ${sourceItem.exposedData.join(', ')}',
        ),
      ),
    );
    if (id != null && mounted) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              CaseDetailsPage(controller: widget.casesController, caseId: id),
        ),
      );
    }
  }

  void _openGuardAi() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => GuardAiPage(
        controller: widget.guardAiController,
        casesController: widget.casesController,
      ),
    ),
  );

  void _openAllCases() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => CasesPage(controller: widget.casesController),
    ),
  );

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
        return Scaffold(
          extendBody: true,
          appBar: AppBar(
            toolbarHeight: 72,
            title: const Text(
              "Osisn't",
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1),
            ),
            leading: Builder(
              builder: (context) => IconButton(
                key: const Key('dashboard-profile-button'),
                tooltip: 'Abrir perfil',
                style: _tourStep == 4
                    ? IconButton.styleFrom(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      )
                    : null,
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: Icon(
                  _tourStep == 4 ? Icons.person_pin : Icons.menu_rounded,
                ),
              ),
            ),
            actions: [
              IconButton(
                focusNode: _helpFocus,
                tooltip: 'Ayuda de uso',
                onPressed: _openHelp,
                icon: const Icon(Icons.help_outline),
              ),
            ],
          ),
          drawer: ProfileDrawer(
            identity: widget.account.email,
            accountName: widget.account.name,
            onManageAccounts: widget.onManageAccounts,
            caseCount: widget.casesController.state.cases.length,
            onViewCases: _openAllCases,
            onHelp: _openHelp,
          ),
          bottomNavigationBar: FootprintActionBar(
            scanning: footprint.isLoading,
            tourStep: _tourStep,
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
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  DashboardStatus(footprint: footprint),
                                  if (_tourStep != null && _tourStep != 1)
                                    _tourPanel(),
                                  if (profile != null) ...[
                                    ExposureGauge(profile: profile),
                                    const SizedBox(height: 20),
                                    RecommendationCard(
                                      casesController: widget.casesController,
                                      featuredItem: featuredItem,
                                      onGuardAi: _openGuardAi,
                                      onViewAllCases: _openAllCases,
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
        );
      },
    );
  }
}
