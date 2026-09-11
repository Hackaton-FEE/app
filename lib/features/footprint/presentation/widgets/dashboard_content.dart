import 'package:flutter/material.dart';

import '../../domain/footprint_item.dart';
import '../footprint_controller.dart';
import '../scan_history_controller.dart';
import 'dashboard_status.dart';
import 'exposure_gauge.dart';
import 'footprint_action_bar.dart';
import 'footprint_explorer.dart';

class DashboardContent extends StatelessWidget {
  const DashboardContent({
    required this.footprint,
    required this.history,
    required this.scrollController,
    required this.region,
    required this.tourStep,
    required this.tourPanel,
    required this.tourTargets,
    required this.onFindingSelected,
    super.key,
  });
  final FootprintController footprint;
  final ScanHistoryController? history;
  final ScrollController scrollController;
  final Widget Function(Widget, int) region;
  final int? tourStep;
  final Widget? tourPanel;
  final List<GlobalKey> tourTargets;
  final ValueChanged<FootprintItem> onFindingSelected;

  Widget wrap(Widget child, [int step = -1]) => region(child, step);

  @override
  Widget build(BuildContext context) {
    final profile = footprint.profile;
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: CustomScrollView(
            key: const Key('dashboard-scroll'),
            controller: scrollController,
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
                            wrap(
                              DashboardStatus(
                                footprint: footprint,
                                history: history,
                              ),
                            ),
                            if (tourStep != null && tourStep != 1) tourPanel!,
                            if (profile != null) ...[
                              wrap(
                                ExposureGauge(
                                  key: tourTargets[0],
                                  profile: profile,
                                ),
                                0,
                              ),
                              const SizedBox(height: 28),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (tourStep == 1) SliverToBoxAdapter(child: tourPanel!),
                    if (profile != null)
                      FootprintExplorer(
                        tourTargetKey: tourTargets[1],
                        tourStep: tourStep,
                        profile: profile,
                        visibleItems: footprint.visibleItems,
                        selectedCategory: footprint.selectedCategory,
                        onCategorySelected: footprint.setCategoryFilter,
                        onFindingSelected: onFindingSelected,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
