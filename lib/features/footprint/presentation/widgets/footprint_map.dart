import 'package:flutter/material.dart';

import '../../domain/footprint_item.dart';

/// An accessible overview of the categories in the current footprint.
class FootprintMap extends StatelessWidget {
  const FootprintMap({
    required this.items,
    required this.onCategorySelected,
    super.key,
  });

  final List<FootprintItem> items;
  final ValueChanged<FootprintCategory> onCategorySelected;

  static const _categories = [
    _MapCategory(
      category: FootprintCategory.socialProfile,
      label: 'Redes',
      icon: Icons.people_outline_rounded,
      foreground: Color(0xFF386B68),
      background: Color(0xFFE6F0EA),
    ),
    _MapCategory(
      category: FootprintCategory.exposedContact,
      label: 'Contacto',
      icon: Icons.alternate_email_rounded,
      foreground: Color(0xFF526F83),
      background: Color(0xFFEAF0F3),
    ),
    _MapCategory(
      category: FootprintCategory.dataBroker,
      label: 'Directorios',
      icon: Icons.manage_search_rounded,
      foreground: Color(0xFF7B6943),
      background: Color(0xFFF3EEDF),
    ),
    _MapCategory(
      category: FootprintCategory.dataBreach,
      label: 'Filtraciones',
      icon: Icons.lock_reset_rounded,
      foreground: Color(0xFF875746),
      background: Color(0xFFF4E9E1),
    ),
  ];

  int _count(FootprintCategory category) =>
      items.where((item) => item.category == category).length;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
        final compact = constraints.maxWidth < 340 || largeText;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _MapIdentity(compact: true),
              ),
              for (final entry in _categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CategoryNode(
                    entry: entry,
                    count: _count(entry.category),
                    compact: true,
                    onPressed: () => onCategorySelected(entry.category),
                  ),
                ),
            ],
          );
        }

        return SizedBox(
          height: 272,
          child: CustomPaint(
            painter: _MapConnections(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Stack(
              children: [
                const Center(child: _MapIdentity()),
                for (var index = 0; index < _categories.length; index++)
                  Positioned(
                    top: index < 2 ? 4 : null,
                    bottom: index >= 2 ? 4 : null,
                    left: index.isEven ? 0 : null,
                    right: index.isOdd ? 0 : null,
                    width: 116,
                    height: 100,
                    child: _CategoryNode(
                      entry: _categories[index],
                      count: _count(_categories[index].category),
                      onPressed: () =>
                          onCategorySelected(_categories[index].category),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapIdentity extends StatelessWidget {
  const _MapIdentity({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = ExcludeSemantics(
      child: Container(
        width: compact ? 36 : 58,
        height: compact ? 36 : 58,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person_outline_rounded,
          size: compact ? 22 : 30,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
    final label = Text(
      'Tu huella',
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
      ),
    );

    if (compact) {
      return Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(child: label),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [icon, const SizedBox(height: 8), label],
    );
  }
}

class _CategoryNode extends StatelessWidget {
  const _CategoryNode({
    required this.entry,
    required this.count,
    required this.onPressed,
    this.compact = false,
  });

  final _MapCategory entry;
  final int count;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text(
      entry.label,
      textAlign: compact ? TextAlign.start : TextAlign.center,
      style: theme.textTheme.labelLarge?.copyWith(
        color: entry.foreground,
        fontWeight: FontWeight.w600,
      ),
    );
    final countLabel = Text(
      '$count',
      style: theme.textTheme.titleMedium?.copyWith(
        color: entry.foreground,
        fontWeight: FontWeight.w700,
      ),
    );
    final icon = Icon(entry.icon, size: 22, color: entry.foreground);

    return Semantics(
      button: true,
      label: '${entry.label}, $count ${count == 1 ? 'hallazgo' : 'hallazgos'}',
      hint: 'Mostrar esta categoría en la lista',
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Material(
          color: entry.background,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('footprint-map-${entry.category.name}'),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64, minWidth: 48),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 16 : 8,
                  vertical: compact ? 12 : 6,
                ),
                child: compact
                    ? Row(
                        children: [
                          icon,
                          const SizedBox(width: 12),
                          Expanded(child: label),
                          const SizedBox(width: 12),
                          countLabel,
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              icon,
                              const SizedBox(width: 8),
                              countLabel,
                            ],
                          ),
                          const SizedBox(height: 5),
                          label,
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapCategory {
  const _MapCategory({
    required this.category,
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final FootprintCategory category;
  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
}

class _MapConnections extends CustomPainter {
  const _MapConnections({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    final nodes = [
      const Offset(58, 54),
      Offset(size.width - 58, 54),
      Offset(58, size.height - 54),
      Offset(size.width - 58, size.height - 54),
    ];

    for (final node in nodes) {
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..cubicTo(node.dx, center.dy, center.dx, node.dy, node.dx, node.dy);
      canvas.drawPath(path, paint);
    }

    canvas.drawCircle(center, 61, paint..color = color.withValues(alpha: 0.07));
  }

  @override
  bool shouldRepaint(covariant _MapConnections oldDelegate) =>
      color != oldDelegate.color;
}
