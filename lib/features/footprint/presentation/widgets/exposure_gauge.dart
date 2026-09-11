import 'package:flutter/material.dart';

import '../../../../app/palette.dart';
import '../../domain/footprint_item.dart';
import '../footprint_labels.dart';
import 'osint_report_card.dart';
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
            'Evaluación de seguridad',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppPalette.olive,
            ),
          ),
          const SizedBox(height: 18),
          Semantics(
            label: profile.hasScanned
                ? 'Índice de exposición: $score de 100'
                : 'Índice de exposición: sin auditar',
            excludeSemantics: true,
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text(
                  profile.hasScanned ? '$score' : '—',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 56,
                    height: 1,
                    letterSpacing: -2,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface,
                  ),
                ),
                if (profile.hasScanned)
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
          if (profile.hasScanned)
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
            !profile.hasScanned ? 'Sin auditar' : risk.exposureLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppPalette.deepOlive,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            !profile.hasScanned
                ? 'Aún no se ha realizado ninguna auditoría para esta identidad.'
                : 'Empieza por los hallazgos de mayor prioridad.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppPalette.olive,
            ),
          ),
          const SizedBox(height: 20),
          if (profile.hasScanned)
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
          if (profile.osintReport case final report?) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
            OsintReportCard(report: report),
          ],
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
