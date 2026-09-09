import 'package:flutter/material.dart';

import '../../domain/footprint_item.dart';
import '../../domain/footprint_profile.dart';
import 'finding_card.dart';
import 'footprint_map.dart';

/// A sliver section sharing the dashboard's viewport with its overview.
class FootprintExplorer extends StatefulWidget {
  const FootprintExplorer({
    required this.profile,
    required this.visibleItems,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onFindingSelected,
    super.key,
  });

  final FootprintProfile profile;
  final List<FootprintItem> visibleItems;
  final FootprintCategory? selectedCategory;
  final ValueChanged<FootprintCategory?> onCategorySelected;
  final ValueChanged<FootprintItem> onFindingSelected;

  @override
  State<FootprintExplorer> createState() => _FootprintExplorerState();
}

class _FootprintExplorerState extends State<FootprintExplorer> {
  bool _showMap = false;

  static const _filters = [
    ('all', 'Todos', null),
    ('social', 'Redes', FootprintCategory.socialProfile),
    ('contacts', 'Contacto', FootprintCategory.exposedContact),
    ('brokers', 'Directorios', FootprintCategory.dataBroker),
    ('breaches', 'Filtraciones', FootprintCategory.dataBreach),
  ];

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'hace un momento';
    if (difference.inHours < 1) return 'hace ${difference.inMinutes} min';
    if (difference.inDays < 1) return 'hace ${difference.inHours} h';
    return 'hace ${difference.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.visibleItems;
    final counts = <FootprintCategory, int>{};
    for (final item in widget.profile.items) {
      counts.update(item.category, (count) => count + 1, ifAbsent: () => 1);
    }
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Explora tu huella',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Lista'),
                      icon: Icon(Icons.view_list_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Mapa'),
                      icon: Icon(Icons.hub_outlined),
                    ),
                  ],
                  selected: {_showMap},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _showMap = value.first),
                  style: SegmentedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              if (_showMap) ...[
                const SizedBox(height: 16),
                FootprintMap(
                  items: widget.profile.items,
                  onCategorySelected: (category) {
                    if (widget.selectedCategory != category) {
                      widget.onCategorySelected(category);
                    }
                    setState(() => _showMap = false);
                  },
                ),
              ],
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (key, label, category) in _filters)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          key: Key('filter-$key'),
                          label: Text(
                            '$label ${category == null ? widget.profile.items.length : counts[category] ?? 0}',
                          ),
                          selected: widget.selectedCategory == category,
                          onSelected: (_) =>
                              widget.onCategorySelected(category),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  '${items.length} hallazgos de ejemplo',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        if (items.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text('No hay hallazgos en esta categoría.'),
            ),
          )
        else
          SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return FindingCard(
                key: Key('finding-card-${item.id}'),
                item: item,
                onTap: () => widget.onFindingSelected(item),
              );
            },
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Ejemplo actualizado ${_formatTimeAgo(widget.profile.lastScannedAt)}. '
              'No se han consultado fuentes externas.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
