import 'package:flutter/material.dart';

import '../../../../app/palette.dart';
import '../../domain/footprint_item.dart';
import '../footprint_labels.dart';
import '../../domain/footprint_profile.dart';

class ExposureGauge extends StatelessWidget {
  const ExposureGauge({required this.profile, super.key});

  final FootprintProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final risk = profile.overallRisk;
    final riskColor = risk.color;
    final score = profile.exposureScore;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Índice de exposición',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'DEMO · Muestra orientativa',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppPalette.olive,
            ),
          ),
          const SizedBox(height: 18),
          Semantics(
            label: 'Índice de exposición de ejemplo: $score de 100',
            excludeSemantics: true,
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text(
                  '$score',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 56,
                    height: 1,
                    letterSpacing: -2,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '/100',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppPalette.olive,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ExcludeSemantics(
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: colors.surface.withValues(alpha: 0.7),
              color: riskColor,
              stopIndicatorRadius: 0,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            risk.exposureLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppPalette.deepOlive,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Empieza por los hallazgos de mayor prioridad.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppPalette.olive,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _PriorityCount(
                label: 'alta',
                count: profile.highRiskCount,
                color: FootprintRisk.high.color,
              ),
              _PriorityCount(
                label: 'media',
                count: profile.mediumRiskCount,
                color: FootprintRisk.medium.color,
              ),
              _PriorityCount(
                label: 'baja',
                count: profile.lowRiskCount,
                color: FootprintRisk.low.color,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorityCount extends StatelessWidget {
  const _PriorityCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Icon(Icons.circle, color: color, size: 8)),
        const SizedBox(width: 6),
        Text(
          '$count $label',
          semanticsLabel: '$count hallazgos de prioridad $label',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: AppPalette.deepOlive),
        ),
      ],
    );
  }
}
