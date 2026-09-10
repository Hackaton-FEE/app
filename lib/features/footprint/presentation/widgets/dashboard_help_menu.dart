import 'package:flutter/material.dart';

class DashboardHelpMenu extends StatelessWidget {
  const DashboardHelpMenu({
    required this.onHelp,
    required this.onScan,
    required this.onGuardAi,
    required this.onCases,
    super.key,
  });

  final VoidCallback onHelp;
  final VoidCallback onScan;
  final VoidCallback onGuardAi;
  final VoidCallback onCases;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Ayuda de uso',
    icon: const Icon(Icons.help_outline),
    onSelected: (value) {
      if (value == 'guide') {
        onHelp();
      } else {
        showDialog<void>(
          context: context,
          builder: (_) => _DashboardTour(
            onScan: onScan,
            onGuardAi: onGuardAi,
            onCases: onCases,
          ),
        );
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: 'tour',
        child: Text('¿Quieres un recorrido interactivo?'),
      ),
      PopupMenuItem(value: 'guide', child: Text('Guía de uso')),
    ],
  );
}

class _DashboardTour extends StatefulWidget {
  const _DashboardTour({
    required this.onScan,
    required this.onGuardAi,
    required this.onCases,
  });

  final VoidCallback onScan;
  final VoidCallback onGuardAi;
  final VoidCallback onCases;

  @override
  State<_DashboardTour> createState() => _DashboardTourState();
}

class _DashboardTourState extends State<_DashboardTour> {
  int _step = 0;
  static const _steps = [
    (
      'Tu huella digital',
      'El indicador resume la exposición del perfil de ejemplo. Revisa los hallazgos y toca sus tarjetas para conocer los detalles.',
      Icons.fingerprint_rounded,
    ),
    (
      'Explora los hallazgos',
      'Alterna entre lista y mapa, y selecciona una categoría para filtrar los resultados. Los datos son simulados.',
      Icons.explore_outlined,
    ),
    (
      'Escanear',
      'El botón inferior Escanear abre un análisis de ejemplo. Puedes probarlo ahora o continuar el recorrido.',
      Icons.manage_search_rounded,
    ),
    (
      'Habla con GuardAI',
      'El botón inferior GuardAI abre el chat. Elige un problema, sigue la guía y pide preparar un reporte para desplegar su formulario flotante.',
      Icons.auto_awesome_outlined,
    ),
    (
      'Tu espacio y tus casos',
      'En la barra lateral puedes consultar casos, cerrar la sesión de ejemplo y encontrar Ayuda al final. Los casos permanecen en el dispositivo.',
      Icons.folder_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final (title, description, icon) = _steps[_step];
    final action = switch (_step) {
      2 => widget.onScan,
      3 => widget.onGuardAi,
      4 => widget.onCases,
      _ => null,
    };
    return AlertDialog(
      scrollable: true,
      title: Semantics(header: true, child: Text(title)),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 48)),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text('Paso ${_step + 1} de ${_steps.length}'),
          ),
          const SizedBox(height: 12),
          Text(description),
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: action,
              child: Text(switch (_step) {
                2 => 'Probar escaneo',
                3 => 'Abrir GuardAI',
                _ => 'Ver mis casos',
              }),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Salir del recorrido'),
        ),
        if (_step > 0)
          TextButton(
            onPressed: () => setState(() => _step--),
            child: const Text('Anterior'),
          ),
        FilledButton(
          onPressed: () {
            if (_step == _steps.length - 1) {
              Navigator.of(context).pop();
            } else {
              setState(() => _step++);
            }
          },
          child: Text(_step == _steps.length - 1 ? 'Finalizar' : 'Siguiente'),
        ),
      ],
    );
  }
}
