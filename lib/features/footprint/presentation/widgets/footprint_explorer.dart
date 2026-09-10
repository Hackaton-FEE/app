import 'package:flutter/material.dart';

import '../../domain/footprint_item.dart';
import '../../domain/footprint_profile.dart';
import 'finding_card.dart';
import 'dashboard_spotlight.dart';
import 'footprint_map.dart';

/// A sliver section sharing the dashboard's viewport with its overview.
class FootprintExplorer extends StatefulWidget {
  const FootprintExplorer({
    required this.profile,
    required this.visibleItems,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onFindingSelected,
    this.tourTargetKey,
    this.tourStep,
    super.key,
  });

  final Key? tourTargetKey;
  final int? tourStep;
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
          child: RepaintBoundary(
            key: widget.tourTargetKey,
            child: SpotlightRegion(
              dimmed: widget.tourStep != null && widget.tourStep != 1,
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
                      '${items.length} hallazgos detectados',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
        if (items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      widget.profile.hasScanned
                          ? Icons.check_circle_outline_rounded
                          : Icons.radar_outlined,
                      size: 36,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.profile.hasScanned
                          ? 'No hay hallazgos en esta categoría.'
                          : 'Sin hallazgos registrados.',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.profile.hasScanned
                          ? 'Tu huella se encuentra limpia en los parámetros seleccionados.'
                          : 'Inicia un escaneo para auditar fuentes públicas y filtraciones.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return SpotlightRegion(
                dimmed: widget.tourStep != null,
                child: FindingCard(
                  key: Key('finding-card-${item.id}'),
                  item: item,
                  onTap: () => widget.onFindingSelected(item),
                ),
              );
            },
          ),
        SliverToBoxAdapter(
          child: SpotlightRegion(
            dimmed: widget.tourStep != null,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                widget.profile.hasScanned
                    ? 'Última actualización ${_formatTimeAgo(widget.profile.lastScannedAt)}.'
                    : 'Aún no se ha realizado ninguna auditoría.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
