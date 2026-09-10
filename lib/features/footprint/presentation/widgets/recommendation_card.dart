import 'package:flutter/material.dart';

import '../../../cases/presentation/cases_controller.dart';
import '../../domain/footprint_item.dart';

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    this.casesController,
    this.historyCount = 0,
    this.onViewHistory,
    required this.featuredItem,
    required this.onGuardAi,
    this.onViewAllCases,
    super.key,
  });

  final CasesController? casesController;
  final int historyCount;
  final VoidCallback? onViewHistory;
  final FootprintItem? featuredItem;
  final VoidCallback onGuardAi;
  final VoidCallback? onViewAllCases;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final casesCount = casesController?.state.cases.length ?? 0;
    final callback = onViewHistory ?? onViewAllCases;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Tu siguiente paso',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            featuredItem != null
                ? 'Conversa con GuardAI sobre lo que quieres revisar y aclara tus próximos pasos.'
                : 'Empieza con una pregunta. GuardAI te acompaña paso a paso.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                key: const Key('recommendation-guardai-button'),
                onPressed: onGuardAi,
                icon: const Icon(Icons.auto_awesome_outlined, size: 20),
                label: const Text('Hablar con GuardAI'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
              if (callback != null)
                TextButton(
                  key: onViewHistory != null
                      ? const Key('recommendation-view-history-button')
                      : const Key('recommendation-view-cases-button'),
                  onPressed: callback,
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: Text(
                    onViewHistory != null
                        ? (historyCount > 0
                              ? 'Historial de escaneos ($historyCount)'
                              : 'Historial de escaneos')
                        : (casesCount > 0
                              ? 'Casos del dispositivo ($casesCount)'
                              : 'Casos del dispositivo'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Orientación de ejemplo. No consulta fuentes externas ni envía solicitudes.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
