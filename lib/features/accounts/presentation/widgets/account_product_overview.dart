import 'package:flutter/material.dart';

/// Product information beneath the selector, with an anchor on its first panel.
class AccountProductOverview extends StatelessWidget {
  const AccountProductOverview({required this.firstPanelKey, super.key});

  final Key firstPanelKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: firstPanelKey,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            key: const Key('account-marketing'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TU VIDA DIGITAL, CON PERSPECTIVA',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onPrimary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  'Menos dudas.\nMás control.',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Lo que compartes cuenta una historia. Explora tu huella, entiende lo que ves y encuentra tu siguiente paso.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onPrimary,
                ),
              ),
              const SizedBox(height: 24),
              ExcludeSemantics(
                child: Icon(
                  Icons.hub_outlined,
                  size: 64,
                  color: colors.onPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        Card(
          color: colors.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: colors.primary,
                  size: 28,
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    'Conoce a GuardAI',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Una conversación para empezar a entender. Sin tener todas las respuestas desde el primer mensaje.',
                ),
                const SizedBox(height: 12),
                Text(
                  'Asistencia interactiva para auditar tu huella digital y resolver incidentes de privacidad paso a paso.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'A tu ritmo. Desde un solo lugar.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}
