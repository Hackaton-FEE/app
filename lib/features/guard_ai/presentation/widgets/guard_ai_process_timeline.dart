import 'package:flutter/material.dart';

import '../../../../app/palette.dart';
import '../../domain/guard_ai_action_executor.dart';

class GuardAiProcessTimeline extends StatelessWidget {
  const GuardAiProcessTimeline({required this.statuses, super.key});
  final List<GuardAiStepStatus> statuses;

  @override
  Widget build(BuildContext context) {
    final horizontal =
        MediaQuery.sizeOf(context).width >= 368 &&
        MediaQuery.textScalerOf(context).scale(14) <= 19;
    if (!horizontal) {
      return Column(
        children: [
          for (var i = 0; i < statuses.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _circle(i),
                const SizedBox(width: 16),
                Expanded(child: _description(i, TextAlign.start)),
              ],
            ),
            if (i < statuses.length - 1)
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 25),
                  child: SizedBox(
                    width: 2,
                    height: 28,
                    child: CustomPaint(painter: _Dots(vertical: true)),
                  ),
                ),
              ),
          ],
        ],
      );
    }
    return Stack(
      children: [
        Positioned(
          top: 25,
          left: 0,
          right: 0,
          child: const Center(
            child: FractionallySizedBox(
              widthFactor: 2 / 3,
              child: SizedBox(height: 2, child: CustomPaint(painter: _Dots())),
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < statuses.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      _circle(i),
                      const SizedBox(height: 12),
                      _description(i, TextAlign.center),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _circle(int index) {
    final status = statuses[index];
    final background = switch (status) {
      GuardAiStepStatus.completed => AppPalette.successContainer,
      GuardAiStepStatus.failed => AppPalette.errorContainer,
      GuardAiStepStatus.running => AppPalette.paleCream,
      GuardAiStepStatus.pending => AppPalette.card,
    };
    return Semantics(
      label: 'Paso ${index + 1}: ${_label(status)}',
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey('process-step-$index-${status.name}'),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: background,
            border: Border.all(
              color: status == GuardAiStepStatus.running
                  ? AppPalette.deepOlive
                  : AppPalette.cardBorder,
              width: 2,
            ),
          ),
          child: Center(
            child: switch (status) {
              GuardAiStepStatus.completed => const Icon(
                Icons.check,
                color: AppPalette.deepOlive,
              ),
              GuardAiStepStatus.failed => const Icon(
                Icons.close,
                color: AppPalette.deepOlive,
              ),
              GuardAiStepStatus.running => const Icon(
                Icons.more_horiz,
                color: AppPalette.deepOlive,
              ),
              GuardAiStepStatus.pending => Text(
                '${index + 1}',
                style: const TextStyle(color: AppPalette.olive),
              ),
            },
          ),
        ),
      ),
    );
  }

  Widget _description(int index, TextAlign alignment) => Column(
    crossAxisAlignment: alignment == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      Text(
        guardAiProcessSteps[index].title,
        textAlign: alignment,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(guardAiProcessSteps[index].description, textAlign: alignment),
      const SizedBox(height: 6),
      Text(
        statuses[index] == GuardAiStepStatus.completed
            ? 'Listo'
            : _label(statuses[index]),
        textAlign: alignment,
        style: const TextStyle(color: AppPalette.olive, fontSize: 12),
      ),
    ],
  );

  String _label(GuardAiStepStatus status) => switch (status) {
    GuardAiStepStatus.pending => 'Pendiente',
    GuardAiStepStatus.running => 'En curso',
    GuardAiStepStatus.completed => 'Completado',
    GuardAiStepStatus.failed => 'Error',
  };
}

class _Dots extends CustomPainter {
  const _Dots({this.vertical = false});
  final bool vertical;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppPalette.warmKhaki;
    final length = vertical ? size.height : size.width;
    for (double offset = 3; offset < length; offset += 8) {
      canvas.drawCircle(
        vertical
            ? Offset(size.width / 2, offset)
            : Offset(offset, size.height / 2),
        1.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Dots oldDelegate) =>
      oldDelegate.vertical != vertical;
}
