import 'package:flutter/material.dart';

import '../../../cases/presentation/cases_controller.dart';
import '../../domain/footprint_item.dart';

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    required this.casesController,
    required this.featuredItem,
    required this.onGuardAi,
    required this.onViewAllCases,
    super.key,
  });

  final CasesController casesController;
  final FootprintItem? featuredItem;
  final VoidCallback onGuardAi;
  final VoidCallback onViewAllCases;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final casesCount = casesController.state.cases.length;

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
              TextButton(
                key: const Key('recommendation-view-cases-button'),
                onPressed: onViewAllCases,
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                child: Text(
                  casesCount > 0
                      ? 'Casos del dispositivo ($casesCount)'
                      : 'Casos del dispositivo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Conversación de ejemplo, sin enviar solicitudes.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
