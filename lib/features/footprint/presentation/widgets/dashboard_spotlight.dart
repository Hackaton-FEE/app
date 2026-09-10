import 'package:flutter/material.dart';

/// Paints around the real controls without copying them or opening a route.
/// Geometry is resolved during paint so scrolling and resizing stay aligned.
class DashboardSpotlight extends StatelessWidget {
  const DashboardSpotlight({
    required this.child,
    required this.surfaceKey,
    required this.panelKey,
    required this.targetKey,
    required this.scrollController,
    required this.enabled,
    required this.targetInBody,
    required this.bottomInset,
    super.key,
  });

  final Widget child;
  final GlobalKey surfaceKey;
  final GlobalKey panelKey;
  final GlobalKey targetKey;
  final ScrollController scrollController;
  final bool enabled;
  final bool targetInBody;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return RepaintBoundary(
      key: surfaceKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (enabled)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    key: const Key('dashboard-spotlight'),
                    painter: DashboardSpotlightPainter(
                      surfaceKey: surfaceKey,
                      panelKey: panelKey,
                      targetKey: targetKey,
                      scrollController: scrollController,
                      bodyTop: media.padding.top + 72,
                      bodyBottom: bottomInset,
                      targetInBody: targetInBody,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DashboardSpotlightPainter extends CustomPainter {
  DashboardSpotlightPainter({
    required this.surfaceKey,
    required this.panelKey,
    required this.targetKey,
    required ScrollController scrollController,
    required this.bodyTop,
    required this.bodyBottom,
    required this.targetInBody,
  }) : super(repaint: scrollController);

  final GlobalKey surfaceKey;
  final GlobalKey panelKey;
  final GlobalKey targetKey;
  final double bodyTop;
  final double bodyBottom;
  final bool targetInBody;

  Rect? _rect(GlobalKey key) {
    final surface = surfaceKey.currentContext?.findRenderObject();
    final target = key.currentContext?.findRenderObject();
    if (surface is! RenderBox || target is! RenderBox || !target.hasSize) {
      return null;
    }
    return target.localToGlobal(Offset.zero, ancestor: surface) & target.size;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    final body = Rect.fromLTRB(
      0,
      bodyTop,
      size.width,
      size.height - bodyBottom,
    );
    final panelBounds = _rect(panelKey);
    // The panel includes 20 px of trailing spacing, outside its visible card.
    final panel = panelBounds == null
        ? null
        : Rect.fromLTRB(
            panelBounds.left,
            panelBounds.top,
            panelBounds.right,
            panelBounds.bottom - 20,
          ).intersect(body);
    final target = _rect(targetKey)
        ?.inflate(5)
        .intersect(targetInBody ? body : screen);
    var shade = Path()..addRect(screen);
    for (final rect in [panel, target]) {
      if (rect == null || rect.isEmpty) continue;
      shade = Path.combine(
        PathOperation.difference,
        shade,
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24))),
      );
    }
    canvas.drawPath(shade, Paint()..color = const Color(0xB8000000));
    if (target != null && !target.isEmpty) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(target, const Radius.circular(24)),
        Paint()
          ..color = const Color(0xFFFFF3B0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DashboardSpotlightPainter oldDelegate) => true;
}

/// Dimmed controls do not compete with the active step for input or focus.
class SpotlightRegion extends StatelessWidget {
  const SpotlightRegion({required this.dimmed, required this.child, super.key});
  final bool dimmed;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeFocus(
    excluding: dimmed,
    child: ExcludeSemantics(
      excluding: dimmed,
      child: IgnorePointer(ignoring: dimmed, child: child),
    ),
  );
}
