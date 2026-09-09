import 'package:flutter/material.dart';

class CasesHeader extends StatelessWidget {
  const CasesHeader({required this.onCreate, super.key});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          header: true,
          child: Text(
            'Tu privacidad,\nbajo tu control.',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Reúne tus casos y decide el siguiente paso.'),
        const SizedBox(height: 24),
        Card.filled(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.phonelink_lock_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        container: true,
                        header: true,
                        child: Text(
                          'Guardado en tu dispositivo',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Puedes retomar tus casos al abrir la app. Aún no se envían solicitudes a terceros.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo caso'),
          ),
        ),
      ],
    );
  }
}
