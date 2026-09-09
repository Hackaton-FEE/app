import 'package:flutter/material.dart';

import '../../../shared/presentation/status_notice.dart';
import '../../help/presentation/help_button.dart';
import '../domain/case_input.dart';
import '../domain/privacy_case.dart';
import '../domain/source_link.dart';
import 'case_labels.dart';
import 'cases_controller.dart';

class CaseFormPage extends StatefulWidget {
  const CaseFormPage({required this.controller, this.initialCase, super.key});

  final CasesController controller;
  final PrivacyCase? initialCase;

  @override
  State<CaseFormPage> createState() => _CaseFormPageState();
}

class _CaseFormPageState extends State<CaseFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initialCase?.title);
  late final _sourceUrl = TextEditingController(
    text: widget.initialCase?.sourceUrl.toString(),
  );
  late final _notes = TextEditingController(text: widget.initialCase?.notes);
  late CaseCategory? _category = widget.initialCase?.category;
  final _fieldFocus = {
    const Key('case-title'): FocusNode(),
    const Key('case-url'): FocusNode(),
    const Key('case-category'): FocusNode(),
  };
  String? _error;
  bool _dirty = false;
  bool _allowPop = false;
  bool _confirmingExit = false;

  bool get _hasChanges =>
      _title.text != (widget.initialCase?.title ?? '') ||
      _sourceUrl.text != (widget.initialCase?.sourceUrl.toString() ?? '') ||
      _notes.text != (widget.initialCase?.notes ?? '') ||
      _category != widget.initialCase?.category;

  @override
  void initState() {
    super.initState();
    for (final controller in [_title, _sourceUrl, _notes]) {
      controller.addListener(_trackChanges);
    }
  }

  void _trackChanges() {
    final dirty = _hasChanges;
    if (_dirty != dirty) setState(() => _dirty = dirty);
  }

  @override
  void dispose() {
    _title.dispose();
    _sourceUrl.dispose();
    _notes.dispose();
    for (final node in _fieldFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _leave([String? savedId]) async {
    setState(() => _allowPop = true);
    // PopScope must register the updated permission before a programmatic pop.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(savedId);
  }

  Future<void> _requestExit() async {
    if (widget.controller.state.isSaving || _confirmingExit) return;
    if (!_dirty) return _leave();
    _confirmingExit = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('¿Descartar los cambios?'),
        content: const Text(
          'Todavía no guardaste estos cambios. Puedes seguir editando o salir sin guardarlos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar cambios'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir editando'),
          ),
        ],
      ),
    );
    _confirmingExit = false;
    if (discard == true && mounted) await _leave();
  }

  Future<void> _focusFirstError(
    Set<FormFieldState<Object?>> invalidFields,
  ) async {
    for (final entry in _fieldFocus.entries) {
      if (!invalidFields.any((field) => field.widget.key == entry.key)) {
        continue;
      }
      entry.value.requestFocus();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final fieldContext = entry.value.context;
      if (fieldContext != null && fieldContext.mounted) {
        await Scrollable.ensureVisible(
          fieldContext,
          alignment: 0.15,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
        );
      }
      return;
    }
  }

  Future<void> _save() async {
    if (widget.controller.state.isSaving) return;
    setState(() => _error = null);
    final invalidFields = _formKey.currentState!.validateGranularly();
    if (invalidFields.isNotEmpty) {
      await _focusFirstError(invalidFields);
      return;
    }
    FocusScope.of(context).unfocus();
    try {
      final input = CaseInput(
        title: _title.text,
        sourceUrl: _sourceUrl.text,
        category: _category!,
        notes: _notes.text,
      );
      final saved = await widget.controller.saveCase(
        input,
        id: widget.initialCase?.id,
      );
      if (!mounted) return;
      if (saved != null) {
        await _leave(saved.id);
      } else {
        setState(
          () => _error =
              widget.controller.state.actionError ??
              'No se pudo guardar el caso.',
        );
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final saving = widget.controller.state.isSaving;
        return PopScope<String>(
          canPop: _allowPop || (!saving && !_dirty),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _requestExit();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: _requestExit),
              title: Text(
                widget.initialCase == null ? 'Nuevo caso' : 'Editar caso',
              ),
              actions: [HelpButton(enabled: !saving)],
            ),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              'Organiza lo que está pasando',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'El título, el enlace y el tipo de situación son obligatorios. Las notas son opcionales; escribe solo lo que quieras conservar.',
                          ),
                          const SizedBox(height: 28),
                          Semantics(
                            isRequired: true,
                            child: TextFormField(
                              key: const Key('case-title'),
                              controller: _title,
                              focusNode: _fieldFocus[const Key('case-title')],
                              enabled: !saving,
                              maxLength: CaseInput.maxTitleLength,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Título del caso',
                                hintText:
                                    'Por ejemplo: perfil que usa mi nombre',
                                errorMaxLines: 5,
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Escribe un título para identificar el caso.'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Semantics(
                            isRequired: true,
                            child: TextFormField(
                              key: const Key('case-url'),
                              controller: _sourceUrl,
                              focusNode: _fieldFocus[const Key('case-url')],
                              enabled: !saving,
                              maxLength: CaseInput.maxSourceLinkLength,
                              keyboardType: TextInputType.url,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Enlace del contenido',
                                hintText: 'https://example.com/publicacion',
                                prefixIcon: Icon(Icons.link),
                                errorMaxLines: 5,
                              ),
                              validator: (value) {
                                try {
                                  parseSourceLink(value ?? '');
                                  return null;
                                } on FormatException catch (error) {
                                  return error.message;
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Semantics(
                            isRequired: true,
                            child: DropdownButtonFormField<CaseCategory>(
                              key: const Key('case-category'),
                              focusNode:
                                  _fieldFocus[const Key('case-category')],
                              initialValue: _category,
                              isExpanded: true,
                              isDense: false,
                              itemHeight: null,
                              decoration: const InputDecoration(
                                labelText: 'Tipo de situación',
                                errorMaxLines: 5,
                              ),
                              items: [
                                for (final category in CaseCategory.values)
                                  DropdownMenuItem(
                                    value: category,
                                    child: Text(category.label),
                                  ),
                              ],
                              onChanged: saving
                                  ? null
                                  : (value) => setState(() {
                                      _category = value;
                                      _dirty = _hasChanges;
                                    }),
                              validator: (value) => value == null
                                  ? 'Selecciona un tipo de situación.'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            key: const Key('case-notes'),
                            controller: _notes,
                            enabled: !saving,
                            maxLength: CaseInput.maxNotesLength,
                            minLines: 3,
                            maxLines: 6,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Notas (opcional)',
                              hintText: 'Anota solo lo necesario para recordar el caso.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Se guarda en este dispositivo. Crear un caso no envía una solicitud de retiro.',
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            StatusNotice(message: _error!, isError: true),
                          ],
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            key: const Key('save-case'),
                            onPressed: saving ? null : _save,
                            icon: saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      semanticsLabel: 'Guardando caso',
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text(saving ? 'Guardando…' : 'Guardar caso'),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
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
