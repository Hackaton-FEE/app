import 'package:flutter/material.dart';

import '../../../../app/palette.dart';

class GuardAiThinking extends StatelessWidget {
  const GuardAiThinking({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'GuardAI está preparando la respuesta',
    child: ExcludeSemantics(
      child: Container(
        key: const Key('guard-ai-thinking'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppPalette.scaffold,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppPalette.cardBorder),
        ),
        child: Row(
          children: [
            if (!MediaQuery.disableAnimationsOf(context))
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.more_horiz, size: 22, color: AppPalette.olive),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thinking…',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppPalette.deepOlive,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
