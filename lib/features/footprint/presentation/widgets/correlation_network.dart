import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/footprint_correlation.dart';

/// A bounded neighborhood: only server-provided links to the selected account.
class CorrelationNetwork extends StatelessWidget {
  const CorrelationNetwork({
    required this.selected,
    required this.neighbors,
    required this.onSelected,
    super.key,
  });

  final IdentityNode selected;
  final List<IdentityNode> neighbors;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      const height = 280.0;
      final center = Offset(width / 2, height / 2);
      final radiusX = math.min(110.0, (width - 64) / 2);
      final points = [
        for (var i = 0; i < neighbors.length; i++)
          Offset(
            center.dx + radiusX * math.cos(-math.pi / 2 + i * math.pi / 3),
            center.dy + 100 * math.sin(-math.pi / 2 + i * math.pi / 3),
          ),
      ];
      final colors = Theme.of(context).colorScheme;
      return SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _NetworkLines(center, points, colors.outline),
                ),
              ),
            ),
            Positioned(
              left: center.dx - 28,
              top: center.dy - 28,
              child: Tooltip(
                message: 'Cuenta seleccionada: ${selected.label}',
                child: Semantics(
                  label: 'Cuenta seleccionada: ${selected.label}',
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    child: const Icon(Icons.person_outline),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < neighbors.length; i++)
              Positioned(
                left: points[i].dx - 24,
                top: points[i].dy - 24,
                child: SizedBox.square(
                  dimension: 48,
                  child: FilledButton.tonal(
                    key: ValueKey('correlation-node-${neighbors[i].id}'),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                    ),
                    onPressed: () => onSelected(neighbors[i].id),
                    child: Text(
                      '${i + 1}',
                      semanticsLabel: 'Explorar ${neighbors[i].label}',
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _NetworkLines extends CustomPainter {
  const _NetworkLines(this.center, this.points, this.color);
  final Offset center;
  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (final point in points) {
      canvas.drawLine(center, point, paint);
    }
  }

  @override
  bool shouldRepaint(_NetworkLines oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.color != color ||
      oldDelegate.points != points;
}
