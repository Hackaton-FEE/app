import 'package:flutter/material.dart';

import '../../domain/footprint_correlation.dart';
import '../../domain/osint_report.dart';

class OsintReportCard extends StatelessWidget {
  const OsintReportCard({required this.report, super.key});

  final OsintReport report;

  @override
  Widget build(BuildContext context) {
    final correlation = report.correlation;
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                onPressed: () => _showCorrelation(context, correlation),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('Ver conexiones y cronología'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void _showCorrelation(BuildContext context, FootprintCorrelation correlation) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => CorrelationDetails(
        correlation: correlation,
        scrollController: scrollController,
      ),
    ),
  );
}

String _signalLabel(String key) => switch (key) {
  'username' => 'alias',
  'full_name' => 'nombre',
  'location' => 'ubicación',
  'masked_email' => 'correo enmascarado',
  'masked_phone' => 'teléfono enmascarado',
  'company' => 'empresa',
  'bio' => 'biografía',
  _ => 'otro dato público',
};

class CorrelationDetails extends StatelessWidget {
  const CorrelationDetails({
    required this.correlation,
    required this.scrollController,
    super.key,
  });

  final FootprintCorrelation correlation;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final labels = {for (final n in correlation.nodes) n.id: n.label};
    final sections = <(String, List<String>)>[
      (
        'Conexiones entre cuentas',
        [
          for (final edge in correlation.edges)
            '${labels[edge.source]} y ${labels[edge.target]}\n'
                'Coinciden en: ${edge.shared.map(_signalLabel).join(', ')}',
        ],
      ),
      (
        'Grupos relacionados',
        [
          for (final cluster in correlation.clusters)
            cluster.map((id) => labels[id]!).join(' · '),
        ],
      ),
      (
        'Cronología de registros',
        [
          for (final entry in correlation.timeline.entries)
            '${entry.platform} · ${entry.createdAt}\n'
                'Antigüedad aproximada: ${entry.ageYears.toStringAsFixed(1)} años',
          if (correlation.timeline.oldAccounts.isNotEmpty)
            'Cuentas antiguas: ${correlation.timeline.oldAccounts.join(', ')}. '
                'Su antigüedad no permite saber si siguen activas.',
        ],
      ),
      (
        'Patrones de contacto',
        [
          for (final contact in correlation.contacts)
            '${contact.kind == 'email' ? 'Correo' : 'Teléfono'}: ${contact.pattern}\n'
                '${contact.sources.join(', ')} · ${contact.count} coincidencias\n'
                '${switch (contact.consistentWithProvided) {
                  true => 'Compatible con el dato proporcionado.',
                  false => 'No coincide con el dato proporcionado.',
                  null => 'Sin dato proporcionado para comparar.',
                }}',
        ],
      ),
    ];
    final rows = <Widget>[
      Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Conexiones y cronología',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar conexiones y cronología',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Estas señales sugieren relaciones; no verifican identidad, '
          'titularidad ni actividad reciente. Los contactos permanecen enmascarados.',
        ),
      ),
      for (final (title, values) in sections) ...[
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        if (values.isEmpty)
          const Text('Sin señales disponibles en este escaneo.'),
        for (final value in values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(value),
          ),
      ],
      const SizedBox(height: 24),
    ];
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index],
    );
  }
}
