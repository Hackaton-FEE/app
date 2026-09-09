import 'package:flutter/material.dart';

import 'cases_controller.dart';
import 'new_case_page.dart';

class CasesPage extends StatelessWidget {
  const CasesPage({required this.controller, super.key});

  final CasesController controller;

  Future<void> _newDraft(BuildContext context) async {
    final sourceUrl = await Navigator.of(context)
        .push<Uri>(MaterialPageRoute(builder: (_) => const NewCasePage()));
    if (sourceUrl != null && context.mounted) {
      controller.addDraft(sourceUrl);
    }
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final drafts = controller.drafts;
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Tu privacidad,\nbajo tu control.',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF152D37),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Organiza tus primeros pasos para gestionar '
                      'contenido que expone tu información.',
                    ),
                    const SizedBox(height: 24),
                    Card.filled(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prototipo local',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Los borradores existen solo mientras la app está abierta. '
                              'Todavía no se envían solicitudes de retiro.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _newDraft(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo borrador'),
                    ),
                    const SizedBox(height: 32),
                    Text('Mis borradores', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (drafts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(Icons.folder_open_outlined, size: 48),
                            SizedBox(height: 12),
                            Text('Aún no tienes borradores.'),
                            SizedBox(height: 4),
                            Text('Agrega un enlace de ejemplo para comenzar.'),
                          ],
                        ),
                      ),
                    for (final draft in drafts)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: Text(
                            draft.sourceUrl.host,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: const Text('Borrador · sin enviar'),
                          trailing: IconButton(
                            tooltip: 'Eliminar borrador',
                            onPressed: () => controller.removeDraft(draft.id),
                            icon: const Icon(Icons.delete_outline),
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
