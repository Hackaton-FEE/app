import 'package:flutter/material.dart';

import '../../domain/footprint_correlation.dart';
import 'correlation_details.dart';
import 'correlation_network.dart';

class CorrelationPage extends StatelessWidget {
  const CorrelationPage({required this.correlation, super.key});

  final FootprintCorrelation correlation;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de nexos'),
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Conexiones'),
            Tab(text: 'Cronología y datos'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          children: [
            CorrelationGraph(correlation: correlation),
            _Timeline(correlation: correlation),
          ],
        ),
      ),
    ),
  );
}

class _Timeline extends StatefulWidget {
  const _Timeline({required this.correlation});
  final FootprintCorrelation correlation;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CorrelationDetails(
    correlation: widget.correlation,
    scrollController: _scroll,
  );
}

class CorrelationGraph extends StatefulWidget {
  const CorrelationGraph({required this.correlation, super.key});
  final FootprintCorrelation correlation;

  @override
  State<CorrelationGraph> createState() => _CorrelationGraphState();
}

class _CorrelationGraphState extends State<CorrelationGraph> {
  String? _selectedId;
  int _page = 0;

  void _select(String id) => setState(() {
    _selectedId = id;
    _page = 0;
  });

  Future<void> _chooseAccount(String selectedId) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.75,
        child: Column(
          children: [
            ListTile(
              title: const Text('Elige una cuenta'),
              trailing: IconButton(
                tooltip: 'Cerrar selector de cuentas',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.correlation.nodes.length,
                itemBuilder: (context, index) {
                  final node = widget.correlation.nodes[index];
                  return ListTile(
                    title: Text(node.label),
                    selected: node.id == selectedId,
                    trailing: node.id == selectedId
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(context, node.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted && id != null) _select(id);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.correlation;
    if (data.nodes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Este escaneo no incluye cuentas para mostrar en el mapa.',
          ),
        ),
      );
    }
    final selected = data.nodes.firstWhere(
      (node) => node.id == _selectedId,
      orElse: () => data.nodes.first,
    );
    final edges = data.edges
        .where(
          (edge) => edge.source == selected.id || edge.target == selected.id,
        )
        .toList();
    final neighborIds = {
      for (final edge in edges)
        if (edge.source != selected.id) edge.source,
      for (final edge in edges)
        if (edge.target != selected.id) edge.target,
    };
    final neighbors = data.nodes
        .where((n) => neighborIds.contains(n.id))
        .toList();
    final visible = neighbors.skip(_page * 6).take(6).toList();
    final theme = Theme.of(context);

    return ListView(
      key: const PageStorageKey('correlation-graph-scroll'),
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${data.nodes.length} cuentas · ${data.edges.length} '
          '${data.edges.length == 1 ? 'conexión' : 'conexiones'}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Elige una cuenta y toca sus conexiones para explorar los nexos. '
          'Cada línea representa datos públicos coincidentes; no confirma titularidad.',
        ),
        const SizedBox(height: 20),
        const Text('Cuenta a explorar'),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          key: const Key('correlation-account-picker'),
          onPressed: () => _chooseAccount(selected.id),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 56),
            padding: const EdgeInsets.all(16),
          ),
          icon: const Icon(Icons.expand_more),
          label: Text(selected.label),
        ),
        const SizedBox(height: 12),
        CorrelationNetwork(
          selected: selected,
          neighbors: visible,
          onSelected: _select,
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            '${selected.label}\n${neighbors.length} '
            '${neighbors.length == 1 ? 'cuenta conectada' : 'cuentas conectadas'}',
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        if (neighbors.isEmpty)
          const Text('No se encontraron nexos para esta cuenta en el escaneo.'),
        if (neighbors.length > 6) ...[
          Text(
            'Mostrando ${_page * 6 + 1}–${_page * 6 + visible.length} '
            'de ${neighbors.length} nexos de esta cuenta.',
          ),
          Wrap(
            spacing: 12,
            children: [
              TextButton(
                onPressed: _page > 0 ? () => setState(() => _page--) : null,
                child: const Text('Anteriores'),
              ),
              TextButton(
                onPressed: (_page + 1) * 6 < neighbors.length
                    ? () => setState(() => _page++)
                    : null,
                child: const Text('Siguientes'),
              ),
            ],
          ),
        ],
        for (var index = 0; index < visible.length; index++)
          Card(
            child: ListTile(
              key: ValueKey('correlation-link-${visible[index].id}'),
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(visible[index].label),
              subtitle: Text(
                'Coinciden en: ${edges.where((e) => e.source == visible[index].id || e.target == visible[index].id).expand((e) => e.shared).toSet().map(correlationSignalLabel).join(', ')}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _select(visible[index].id),
            ),
          ),
      ],
    );
  }
}
