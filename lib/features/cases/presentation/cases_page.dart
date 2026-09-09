import 'package:flutter/material.dart';

import 'case_details_page.dart';
import 'case_form_page.dart';
import 'cases_controller.dart';
import 'cases_state.dart';
import 'widgets/case_card.dart';
import 'widgets/cases_empty_state.dart';
import 'widgets/cases_header.dart';

class CasesPage extends StatefulWidget {
  const CasesPage({required this.controller, super.key});

  final CasesController controller;

  @override
  State<CasesPage> createState() => _CasesPageState();
}

class _CasesPageState extends State<CasesPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _createCase() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CaseFormPage(controller: widget.controller),
      ),
    );
    if (id == null || !mounted) return;
    _search.clear();
    widget.controller.search('');
    widget.controller.setFilter(CaseFilter.active);
    _openCase(id);
  }

  void _openCase(String id) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            CaseDetailsPage(controller: widget.controller, caseId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacidad FEE'),
        leading: const Icon(Icons.shield_outlined),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final controller = widget.controller;
                final state = controller.state;
                if (state.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Cargando casos',
                    ),
                  );
                }
                if (state.loadError != null) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline, size: 48),
                          const SizedBox(height: 20),
                          Text(state.loadError!, textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: controller.load,
                            child: const Text('Volver a intentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final cases = controller.visibleCases;
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CasesHeader(
                              onCreate: state.isSaving ? null : _createCase,
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Mis casos',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<CaseFilter>(
                                segments: [
                                  ButtonSegment(
                                    value: CaseFilter.active,
                                    label: Text(
                                      'Activos (${controller.activeCount})',
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: CaseFilter.archived,
                                    label: Text(
                                      'Archivo (${controller.archivedCount})',
                                    ),
                                  ),
                                ],
                                selected: {controller.filter},
                                showSelectedIcon: false,
                                onSelectionChanged: (value) =>
                                    controller.setFilter(value.single),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              key: const Key('search-cases'),
                              controller: _search,
                              onChanged: controller.search,
                              decoration: InputDecoration(
                                hintText: 'Buscar por título o sitio',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: controller.query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Limpiar búsqueda',
                                        onPressed: () {
                                          _search.clear();
                                          controller.search('');
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    if (cases.isEmpty)
                      SliverToBoxAdapter(
                        child: CasesEmptyState(
                          title: controller.query.trim().isNotEmpty
                              ? 'No encontramos coincidencias'
                              : controller.filter == CaseFilter.archived
                              ? 'Tu archivo está vacío'
                              : 'Tu primer paso empieza aquí',
                          description: controller.query.trim().isNotEmpty
                              ? 'Prueba con otro título o nombre del sitio.'
                              : controller.filter == CaseFilter.archived
                              ? 'Los casos que archives aparecerán aquí.'
                              : 'Crea un caso para guardar el enlace y tus notas.',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        sliver: SliverList.builder(
                          itemCount: cases.length,
                          itemBuilder: (context, index) => CaseCard(
                            item: cases[index],
                            onTap: () => _openCase(cases[index].id),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
