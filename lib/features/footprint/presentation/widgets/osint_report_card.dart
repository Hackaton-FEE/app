import 'package:flutter/material.dart';

import 'correlation_graph.dart';
import '../../domain/osint_report.dart';

class OsintReportCard extends StatelessWidget {
  const OsintReportCard({required this.report, super.key});

  final OsintReport report;

  @override
  Widget build(BuildContext context) {
    final correlation = report.correlation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            report.partial ? 'Resultado parcial' : 'Resultado del escaneo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${report.platformsFound} plataformas · '
          '${report.potentialMatches} posibles coincidencias · '
          '${report.rateLimited} consultas limitadas',
        ),
        if (report.partial || report.rateLimited > 0) ...[
          const SizedBox(height: 8),
          const Text(
            'Algunas fuentes no pudieron consultarse. '
            'La ausencia de hallazgos no confirma ausencia de exposición.',
          ),
        ],
        if (correlation != null) ...[
          const SizedBox(height: 12),
          Text(
            '${correlation.edges.length} conexiones entre cuentas · '
            '${correlation.timeline.entries.length} fechas de registro',
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('show-osint-correlation'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => CorrelationPage(correlation: correlation),
              ),
            ),
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('Ver mapa de nexos'),
          ),
        ],
      ],
    );
  }
}
