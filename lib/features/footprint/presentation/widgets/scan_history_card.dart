import 'package:flutter/material.dart';

import '../../domain/footprint_item.dart';
import '../../domain/scan_history_entry.dart';

class ScanHistoryCard extends StatelessWidget {
  const ScanHistoryCard({
    required this.entry,
    required this.onOpen,
    required this.onDelete,
    super.key,
  });
  final ScanHistoryEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = entry.scannedAt.toLocal();
    final remaining = entry.remainingTime();
    final expiry = remaining.inHours < 1
        ? 'Expira pronto'
        : 'Expira en ${remaining.inHours} h';
    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                entry.targetIdentity,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (entry.hasBackendReport)
                    ScanHistoryRiskBadge(risk: entry.overallRisk)
                  else
                    const Text('Origen no verificado'),
                  Text('${date.day}/${date.month}/${date.year} · $expiry'),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (entry.hasBackendReport) ...[
                    Text('Exposición: ${entry.exposureScore}/100'),
                    Text('${entry.findingsCount} hallazgos'),
                  ],
                  IconButton(
                    tooltip: 'Eliminar escaneo',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScanHistoryRiskBadge extends StatelessWidget {
  const ScanHistoryRiskBadge({required this.risk, super.key});
  final FootprintRisk risk;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground, label) = switch (risk) {
      FootprintRisk.high => (
        colors.errorContainer,
        colors.onErrorContainer,
        'Riesgo alto',
      ),
      FootprintRisk.medium => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
        'Riesgo medio',
      ),
      FootprintRisk.low => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
        'Riesgo bajo',
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground),
      ),
    );
  }
}
