import 'package:flutter/material.dart';

import '../../domain/footprint_profile.dart';
import '../../domain/scan_history_entry.dart';
import 'scan_history_card.dart';

void showScanHistoryDetail(
  BuildContext context,
  ScanHistoryEntry entry, {
  ValueChanged<FootprintProfile>? onSelectProfile,
}) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    backgroundColor: colors.surface,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Detalle del escaneo',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.targetIdentity,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              controller: scroll,
              padding: const EdgeInsets.all(24),
              itemCount: entry.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = entry.items[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.platform,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ScanHistoryRiskBadge(risk: item.riskLevel),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        if (item.exposedData.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: item.exposedData.map((d) {
                              return Chip(
                                label: Text(
                                  d,
                                  style: theme.textTheme.labelSmall,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (onSelectProfile != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: SizedBox(
                width: double.infinity,

                child: FilledButton.icon(
                  key: const Key('load-scan-to-dashboard-button'),
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('Cargar en el panel'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onSelectProfile(entry.toProfile());
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
