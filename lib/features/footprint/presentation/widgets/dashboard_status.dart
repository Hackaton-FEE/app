import 'package:flutter/material.dart';

import '../footprint_controller.dart';
import '../scan_history_controller.dart';

class DashboardStatus extends StatelessWidget {
  const DashboardStatus({required this.footprint, this.history, super.key});
  final FootprintController footprint;
  final ScanHistoryController? history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = footprint.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  Text(footprint.scanningStage ?? 'Cargando ejemplo…'),
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
        if (history?.error != null)
          Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(history!.error!),
                OutlinedButton(
                  onPressed: history!.isLoading ? null : history!.retry,
                  child: const Text('Reintentar historial'),
                ),
              ],
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
                      onPressed: footprint.isLoading ? null : footprint.retry,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
