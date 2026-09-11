import 'package:flutter/material.dart';

import '../../../../app/palette.dart';

class GuardAiWelcome extends StatelessWidget {
  const GuardAiWelcome({required this.showIntro, super.key});
  final bool showIntro;

  @override
  Widget build(BuildContext context) {
    if (!showIntro) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 14, color: AppPalette.olive),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'GuardAI',
                style: TextStyle(fontSize: 12, color: AppPalette.olive),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const Align(
          child: CircleAvatar(
            radius: 32,
            backgroundColor: AppPalette.deepOlive,
            child: Icon(
              Icons.shield_outlined,
              size: 32,
              color: AppPalette.paleCream,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            'Tu privacidad, paso a paso',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppPalette.deepOlive,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Entiende tu huella digital.\nDecide qué quieres proteger.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppPalette.olive, height: 1.5),
        ),
        const SizedBox(height: 28),
        Container(
          key: const Key('guard-ai-intro'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppPalette.paleCream,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppPalette.sandGold.withValues(alpha: .4),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este espacio es tuyo',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Escribe tu consulta o usa las acciones rápidas. GuardAI toma como contexto el informe abierto en el dashboard. Evita compartir contraseñas.',
                style: TextStyle(height: 1.5, color: AppPalette.deepOlive),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
