import 'dart:async';

import 'package:flutter/material.dart';

import '../../accounts/domain/local_account.dart';
import '../../guard_ai/presentation/guard_ai_controller.dart';
import '../../guard_ai/presentation/guard_ai_page.dart';
import '../../cases/presentation/case_details_page.dart';
import '../../cases/presentation/case_form_page.dart';
import '../../cases/presentation/cases_controller.dart';
import '../../cases/presentation/cases_page.dart';
import '../../help/presentation/help_button.dart';
import '../../help/presentation/help_page.dart';
import '../domain/footprint_item.dart';
import 'footprint_controller.dart';
import 'widgets/footprint_action_bar.dart';
import 'widgets/footprint_map.dart';
import 'widgets/profile_drawer.dart';
import 'widgets/exposure_gauge.dart';
import 'widgets/finding_card.dart';
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
  bool _showMap = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openHelp() {
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const HelpPage()));
  }

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

  Future<void> _openNewReport({
    String? initialTitle,
    String? initialSourceUrl,
    FootprintItem? sourceItem,
  }) async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CaseFormPage(
          controller: widget.casesController,
          initialTitle:
              initialTitle ??
              (sourceItem != null
                  ? 'Retiro de datos: ${sourceItem.platform}'
                  : null),
          initialSourceUrl: initialSourceUrl ?? sourceItem?.sourceUrl,
          initialCategory: sourceItem?.suggestedCaseCategory,
          initialNotes: sourceItem != null
              ? 'Origen: Hallazgo de demostración de Huella Digital\n${sourceItem.description}\n\nDatos expuestos: ${sourceItem.exposedData.join(', ')}'
              : null,
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

  void _openGuardAi() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GuardAiPage(controller: widget.guardAiController),
      ),
    );
  }

  void _openAllCases() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CasesPage(controller: widget.casesController),
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
      builder: (_) => FootprintDetailSheet(
        item: item,
        onCreateReport: (selectedItem) {
          _openNewReport(sourceItem: selectedItem);
        },
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'hace un momento';
    if (difference.inHours < 1) return 'hace ${difference.inMinutes} min';
    if (difference.inDays < 1) return 'hace ${difference.inHours} h';
    return 'hace ${difference.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
            actions: const [HelpButton(), SizedBox(width: 8)],
          ),
          drawer: ProfileDrawer(
            identity: widget.account.email,
            accountName: widget.account.name,
            onManageAccounts: widget.onManageAccounts,
            caseCount: widget.casesController.state.cases.length,
            onScan: _openScanSheet,
            onViewCases: _openAllCases,
            onHelp: _openHelp,
          ),
          bottomNavigationBar: FootprintActionBar(
            scrollController: _scrollController,
            scanning: footprint.isLoading,
            onScan: _openScanSheet,
            onGuardAi: _openGuardAi,
          ),
          body: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  key: const Key('dashboard-scroll'),
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    8,
                    24,
                    FootprintActionBar.contentHeight(context) +
                        MediaQuery.viewPaddingOf(context).bottom +
                        32,
                  ),
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Tu huella digital',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Entiende qué compartes. Decide qué cambiar.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            profile?.targetIdentity ?? 'Sin identidad evaluada',
                            key: const Key('dashboard-target-identity'),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'VISTA DE EJEMPLO · Datos simulados',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (footprint.isLoading)
                      Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                footprint.scanningStage ?? 'Cargando ejemplo…',
                              ),
                              const SizedBox(height: 12),
                              const LinearProgressIndicator(),
                            ],
                          ),
                        ),
                      ),
                    if (footprint.error != null)
                      Semantics(
                        liveRegion: true,
                        child: Card(
                          color: theme.colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(footprint.error!),
                                TextButton(
                                  onPressed: footprint.isLoading
                                      ? null
                                      : () => footprint.loadProfile(),
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
                      Semantics(
                        header: true,
                        child: Text(
                          'Explora tu huella',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('Lista'),
                              icon: Icon(Icons.view_list_outlined),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('Mapa'),
                              icon: Icon(Icons.hub_outlined),
                            ),
                          ],
                          selected: {_showMap},
                          showSelectedIcon: false,
                          onSelectionChanged: (value) =>
                              setState(() => _showMap = value.first),
                          style: SegmentedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                      if (_showMap) ...[
                        const SizedBox(height: 16),
                        FootprintMap(
                          items: profile.items,
                          onCategorySelected: (category) {
                            if (footprint.selectedCategory != category) {
                              footprint.setCategoryFilter(category);
                            }
                            setState(() => _showMap = false);
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterChip(
                              'all',
                              'Todos',
                              null,
                              profile.items.length,
                            ),
                            _filterChip(
                              'social',
                              'Redes',
                              FootprintCategory.socialProfile,
                              profile.items
                                  .where(
                                    (i) =>
                                        i.category ==
                                        FootprintCategory.socialProfile,
                                  )
                                  .length,
                            ),
                            _filterChip(
                              'contacts',
                              'Contacto',
                              FootprintCategory.exposedContact,
                              profile.items
                                  .where(
                                    (i) =>
                                        i.category ==
                                        FootprintCategory.exposedContact,
                                  )
                                  .length,
                            ),
                            _filterChip(
                              'brokers',
                              'Directorios',
                              FootprintCategory.dataBroker,
                              profile.items
                                  .where(
                                    (i) =>
                                        i.category ==
                                        FootprintCategory.dataBroker,
                                  )
                                  .length,
                            ),
                            _filterChip(
                              'breaches',
                              'Filtraciones',
                              FootprintCategory.dataBreach,
                              profile.items
                                  .where(
                                    (i) =>
                                        i.category ==
                                        FootprintCategory.dataBreach,
                                  )
                                  .length,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '${footprint.visibleItems.length} hallazgos de ejemplo',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (footprint.visibleItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Text('No hay hallazgos en esta categoría.'),
                        )
                      else
                        ...footprint.visibleItems.map(
                          (item) => FindingCard(
                            key: Key('finding-card-${item.id}'),
                            item: item,
                            onTap: () => _showFindingDetail(item),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'Ejemplo actualizado ${_formatTimeAgo(profile.lastScannedAt)}. '
                        'No se han consultado fuentes externas.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filterChip(
    String key,
    String label,
    FootprintCategory? category,
    int count,
  ) {
    final controller = widget.footprintController;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        key: Key('filter-$key'),
        label: Text('$label $count'),
        selected: controller.selectedCategory == category,
        onSelected: (_) => controller.setCategoryFilter(category),
      ),
    );
  }
}
