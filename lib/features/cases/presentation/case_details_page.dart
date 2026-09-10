import 'package:flutter/material.dart';

import '../../../app/palette.dart';
import '../../../shared/presentation/status_notice.dart';
import '../../help/presentation/help_button.dart';
import '../domain/privacy_case.dart';
import 'case_form_page.dart';
import 'case_labels.dart';
import 'cases_controller.dart';

class CaseDetailsPage extends StatefulWidget {
  const CaseDetailsPage({
    required this.controller,
    required this.caseId,
    super.key,
  });

  final CasesController controller;
  final String caseId;

  @override
  State<CaseDetailsPage> createState() => _CaseDetailsPageState();
}

class _CaseDetailsPageState extends State<CaseDetailsPage> {
  final _noticeKey = GlobalKey();
  String? _message;
  bool _isError = false;

  Future<void> _showFeedback(String message, {bool isError = false}) async {
    setState(() {
      _message = message;
      _isError = isError;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final noticeContext = _noticeKey.currentContext;
    if (noticeContext != null && noticeContext.mounted) {
      await Scrollable.ensureVisible(
        noticeContext,
        alignment: 0.5,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
      );
    }
  }

  Future<void> _edit(PrivacyCase item) async {
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            CaseFormPage(controller: widget.controller, initialCase: item),
      ),
    );
    if (saved != null && mounted) {
      await _showFeedback('Cambios guardados en este dispositivo.');
    }
  }

  Future<void> _archive(bool archived) async {
    final saved = await widget.controller.setArchived(widget.caseId, archived);
    if (!mounted) return;
    await _showFeedback(
      saved
          ? archived
                ? 'Caso archivado. Puedes restaurarlo desde este detalle.'
                : 'Caso restaurado. Ahora aparece en Activos.'
          : widget.controller.state.actionError ??
                'No se pudo actualizar el caso. Puedes volver a intentarlo.',
      isError: !saved,
    );
  }

  Future<void> _delete(PrivacyCase item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('¿Eliminar este caso?'),
        content: Text(
          'Se eliminará «${item.title}», con su enlace y notas guardados en este dispositivo. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Conservar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.error,
              foregroundColor: AppPalette.black,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await widget.controller.deleteCase(widget.caseId);
    if (!mounted) return;
    if (deleted) {
      Navigator.of(context).pop();
    } else {
      await _showFeedback(
        widget.controller.state.actionError ??
            'No se pudo eliminar el caso. Puedes volver a intentarlo.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final item = widget.controller.findCase(widget.caseId);
        final busy = widget.controller.state.isSaving;
        final theme = Theme.of(context);
        final dates = MaterialLocalizations.of(context);
        return PopScope(
          canPop: !busy,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Detalle del caso'),
              actions: [HelpButton(enabled: !busy)],
            ),
            body: item == null
                ? const Center(child: Text('Este caso ya no está disponible.'))
                : SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              Semantics(
                                header: true,
                                child: Text(
                                  item.title,
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
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
                                child: SelectableText(
                                  item.sourceUrl.toString(),
                                ),
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
                                'Creado: ${dates.formatFullDate(item.createdAt.toLocal())}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Última edición: ${dates.formatFullDate(item.updatedAt.toLocal())}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 24),
                              if (_message != null) ...[
                                StatusNotice(
                                  key: _noticeKey,
                                  message: _message!,
                                  isError: _isError,
                                  isSuccess: !_isError,
                                ),
                                const SizedBox(height: 16),
                              ],
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
                                onPressed: busy ? null : () => _edit(item),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Editar caso'),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => _archive(
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
                                onPressed: busy ? null : () => _delete(item),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Eliminar caso'),
                                style: TextButton.styleFrom(
                                  backgroundColor: AppPalette.errorContainer,
                                  foregroundColor: AppPalette.textPrimary,
                                ),
                              ),
                            ],
                          ),
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
            Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
