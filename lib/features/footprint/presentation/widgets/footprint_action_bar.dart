import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dashboard_spotlight.dart';

/// A shared bottom surface: the feed scrolls behind its fading edge and pills.
class FootprintActionBar extends StatelessWidget {
  const FootprintActionBar({
    required this.onScan,
    required this.onGuardAi,
    this.scanning = false,
    this.tourStep,
    this.scanKey,
    this.guardAiKey,
    super.key,
  });

  final VoidCallback onScan;
  final VoidCallback onGuardAi;
  final bool scanning;
  final int? tourStep;
  final Key? scanKey;
  final Key? guardAiKey;

  static TextStyle _labelStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge!
          .copyWith(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2);

  static double contentHeight(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final insets = MediaQuery.viewPaddingOf(context);
    final width = math.min(
      520.0,
      MediaQuery.sizeOf(context).width - insets.left - insets.right - 40,
    );
    final labelWidth = (width - 12) / 2 - 24 - (largeText ? 0 : 30);
    var labelHeight = 0.0;
    for (final label in ['Escanear', 'Analizando', 'GuardAI']) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: _labelStyle(context)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: math.max(1, labelWidth));
      labelHeight = math.max(labelHeight, painter.height);
      painter.dispose();
    }
    return math.max(64, labelHeight + 24 + (largeText ? 28 : 0)) + 40;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final highContrast = MediaQuery.highContrastOf(context);
    final insets = MediaQuery.viewPaddingOf(context);
    final bottom = insets.bottom;
    final height = contentHeight(context);

    return RepaintBoundary(
      child: SizedBox(
        key: const Key('dashboard-action-bar'),
        height: height + bottom,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.45, 1],
                    colors: [
                      theme.scaffoldBackgroundColor.withValues(alpha: 0),
                      theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
                      theme.scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20 + insets.left,
                  24,
                  20 + insets.right,
                  bottom + 12,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SpotlightRegion(
                          dimmed: tourStep != null && tourStep != 2,
                          child: _ActionPill(
                            key: scanKey,
                            actionKey: const Key('dashboard-scan-fab'),
                            highlighted: tourStep == 2,
                            label: scanning ? 'Analizando' : 'Escanear',
                            icon: Icons.radar_rounded,
                            onPressed: scanning ? null : onScan,
                            color: theme.colorScheme.surface.withValues(
                              alpha: highContrast ? 1 : 0.94,
                            ),
                            foreground: theme.colorScheme.onSurface,
                            largeText: largeText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SpotlightRegion(
                          dimmed: tourStep != null && tourStep != 3,
                          child: _ActionPill(
                            key: guardAiKey,
                            actionKey: const Key('dashboard-guardai-fab'),
                            highlighted: tourStep == 3,
                            label: 'GuardAI',
                            icon: Icons.auto_awesome_outlined,
                            onPressed: onGuardAi,
                            color: theme.colorScheme.primary,
                            foreground: theme.colorScheme.onPrimary,
                            largeText: largeText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.actionKey,
    required this.highlighted,
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.color,
    required this.foreground,
    required this.largeText,
  });

  final Key actionKey;
  final bool highlighted;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color foreground;
  final bool largeText;

  @override
  Widget build(BuildContext context) {
    final content = largeText
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 4),
              Text(label),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22),
              const SizedBox(width: 8),
              Flexible(child: Text(label)),
            ],
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(largeText ? 28 : 32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextButton(
        key: actionKey,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: color,
          disabledBackgroundColor: color,
          disabledForegroundColor: foreground,
          minimumSize: Size(double.infinity, largeText ? 96 : 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          textStyle: FootprintActionBar._labelStyle(context),
          side: highlighted ? BorderSide(color: foreground, width: 3) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(largeText ? 28 : 32),
          ),
        ),
        child: content,
      ),
    );
  }
}
