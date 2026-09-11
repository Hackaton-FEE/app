import 'package:flutter/material.dart';

import '../../domain/footprint_correlation.dart';

String correlationSignalLabel(String key) => switch (key) {
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
      key: const Key('correlation-details-scroll'),
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index],
    );
  }
}
