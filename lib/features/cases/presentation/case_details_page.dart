import 'package:flutter/material.dart';

import '../domain/privacy_case.dart';
import 'case_form_page.dart';
import 'case_labels.dart';
import 'cases_controller.dart';

class CaseDetailsPage extends StatelessWidget {
  const CaseDetailsPage({
    required this.controller,
    required this.caseId,
    super.key,
  });

  final CasesController controller;
  final String caseId;

  Future<void> _edit(BuildContext context, PrivacyCase item) async {
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CaseFormPage(controller: controller, initialCase: item),
      ),
    );
    if (saved != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cambios guardados.')));
    }
  }

  Future<void> _archive(BuildContext context, bool archived) async {
    final saved = await controller.setArchived(caseId, archived);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? archived
                    ? 'Caso archivado.'
                    : 'Caso restaurado.'
              : controller.state.actionError ??
                    'No se pudo actualizar el caso.',
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar este caso?'),
        content: const Text(
          'Se eliminarán el enlace y las notas guardados en este dispositivo. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Conservar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await controller.deleteCase(caseId);
    if (!context.mounted) return;
    if (deleted) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.state.actionError ?? 'No se pudo eliminar el caso.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final item = controller.findCase(caseId);
        final busy = controller.state.isSaving;
        final theme = Theme.of(context);
        final dates = MaterialLocalizations.of(context);
        return PopScope(
          canPop: !busy,
          child: Scaffold(
            appBar: AppBar(title: const Text('Detalle del caso')),
            body: item == null
                ? const Center(child: Text('Este caso ya no está disponible.'))
                : SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Chip(
                                label: Text(item.status.label),
                                avatar: Icon(
                                  item.status == CaseStatus.archived
                                      ? Icons.inventory_2_outlined
                                      : Icons.edit_note,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              item.title,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item.category.label,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 24),
                            _DetailSection(
                              title: 'Enlace del contenido',
                              child: SelectableText(item.sourceUrl.toString()),
                            ),
                            const SizedBox(height: 16),
                            _DetailSection(
                              title: 'Tus notas',
                              child: SelectableText(
                                item.notes.isEmpty
                                    ? 'Todavía no agregaste notas.'
                                    : item.notes,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Creado: ${dates.formatMediumDate(item.createdAt.toLocal())}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Última edición: ${dates.formatMediumDate(item.updatedAt.toLocal())}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Este caso se guarda en tu dispositivo. Archivarlo solo lo organiza; no significa que el contenido se haya retirado.',
                            ),
                            const SizedBox(height: 24),
                            if (busy)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: LinearProgressIndicator(
                                  semanticsLabel: 'Guardando cambios',
                                ),
                              ),
                            FilledButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => _edit(context, item),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Editar caso'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => _archive(
                                      context,
                                      item.status != CaseStatus.archived,
                                    ),
                              icon: Icon(
                                item.status == CaseStatus.archived
                                    ? Icons.unarchive_outlined
                                    : Icons.archive_outlined,
                              ),
                              label: Text(
                                item.status == CaseStatus.archived
                                    ? 'Restaurar caso'
                                    : 'Archivar caso',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: busy ? null : () => _delete(context),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Eliminar caso'),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
