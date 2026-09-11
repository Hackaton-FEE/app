import 'package:flutter/material.dart';

import '../../../../app/palette.dart';
import '../../domain/guard_ai_profile_report.dart';

class GuardAiProfileReportCard extends StatelessWidget {
  const GuardAiProfileReportCard({required this.report, super.key});
  final GuardAiProfileReport report;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 8),
      const Text(
        'TU PERFIL, EN CLARO',
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.3,
          fontWeight: FontWeight.w700,
          color: AppPalette.olive,
        ),
      ),
      const SizedBox(height: 8),
      Semantics(
        header: true,
        child: Text(
          'Informe de privacidad',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 4),
      Text(report.identity, style: const TextStyle(color: AppPalette.olive)),
      const SizedBox(height: 20),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _badge('alta · ${report.high}', AppPalette.errorContainer),
          _badge('media · ${report.medium}', AppPalette.warningContainer),
          _badge('baja · ${report.low}', AppPalette.successContainer),
        ],
      ),
      const SizedBox(height: 16),
      Text(report.summary, style: const TextStyle(height: 1.5)),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Divider(height: 1),
      ),
      for (final section in report.sections) ...[
        Text(
          section.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(section.description, style: const TextStyle(height: 1.5)),
        const SizedBox(height: 18),
      ],
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppPalette.paleCream,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Por dónde empezar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              report.recommendation,
              style: const TextStyle(height: 1.4, color: AppPalette.deepOlive),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        report.sourceNote,
        style: const TextStyle(
          fontSize: 12,
          height: 1.4,
          color: AppPalette.olive,
        ),
      ),
    ],
  );

  Widget _badge(String text, Color background) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      'Prioridad $text',
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppPalette.deepOlive,
      ),
    ),
  );
}
