import 'package:flutter/material.dart';

/// In-flow guidance: the actual dashboard stays visible and interactive.
class DashboardTourPanel extends StatelessWidget {
  const DashboardTourPanel({
    required this.step,
    required this.focusNode,
    required this.onStep,
    super.key,
  });

  final int step;
  final FocusNode focusNode;
  final ValueChanged<int?> onStep;

  static const _steps = [
    (
      'Conoce tu exposición',
      'El indicador de abajo resume tu huella de ejemplo. No es una probabilidad de daño.',
      Icons.fingerprint_rounded,
      'Revisa el indicador',
    ),
    (
      'Explora los hallazgos',
      'Aquí puedes alternar entre lista y mapa, filtrar por categoría y tocar un hallazgo para ver sus detalles.',
      Icons.explore_outlined,
      'Prueba los filtros y el mapa',
    ),
    (
      'Prueba un escaneo',
      'Toca Escanear en la barra inferior para cambiar el correo o alias del análisis de ejemplo. Los datos son simulados.',
      Icons.radar_rounded,
      'Escanear · botón inferior izquierdo',
    ),
    (
      'Conversa con GuardAI',
      'Toca GuardAI para explorar una duda paso a paso. Al volver, puedes continuar aquí. Las respuestas son ejemplos locales.',
      Icons.auto_awesome_outlined,
      'GuardAI · botón inferior derecho',
    ),
    (
      'Encuentra tus casos',
      'Abre el perfil arriba a la izquierda para consultar los casos del dispositivo o cerrar sesión. Los casos se guardan localmente; no se envían.',
      Icons.person_pin,
      'Abre el perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (title, body, icon, hint) = _steps[step];
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          border: Border.all(color: colors.primary, width: 2),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(child: Icon(icon, size: 36)),
              const SizedBox(height: 12),
              Focus(
                focusNode: focusNode,
                child: Semantics(
                  liveRegion: true,
                  header: true,
                  child: Text(
                    'Paso ${step + 1} de ${_steps.length} · $title',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ExcludeSemantics(
                child: Row(
                  children: List.generate(
                    _steps.length,
                    (index) => Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: index <= step ? colors.primary : colors.surface,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(body),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      step == 4 ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hint,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (step > 0)
                    OutlinedButton(
                      onPressed: () => onStep(step - 1),
                      child: const Text('Anterior'),
                    ),
                  FilledButton(
                    onPressed: () => onStep(step == 4 ? null : step + 1),
                    child: Text(step == 4 ? 'Finalizar' : 'Siguiente'),
                  ),
                  TextButton(
                    onPressed: () => onStep(null),
                    child: const Text('Salir del recorrido'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
