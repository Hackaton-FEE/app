import 'package:flutter/material.dart';

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
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _sourceUrl.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.controller.state.isSaving ||
        !_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
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
        Navigator.of(context).pop(saved.id);
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
        return PopScope(
          canPop: !saving,
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                widget.initialCase == null ? 'Nuevo caso' : 'Editar caso',
              ),
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
                          Text(
                            'Organiza lo que está pasando',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Guarda una referencia del contenido y unas notas para tus próximos pasos.',
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            key: const Key('case-title'),
                            controller: _title,
                            enabled: !saving,
                            maxLength: CaseInput.maxTitleLength,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Título del caso',
                              hintText: 'Por ejemplo: perfil que usa mi nombre',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Escribe un título para identificar el caso.'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('case-url'),
                            controller: _sourceUrl,
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
                              errorMaxLines: 3,
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
                          const SizedBox(height: 12),
                          DropdownButtonFormField<CaseCategory>(
                            key: const Key('case-category'),
                            initialValue: _category,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de situación',
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
                                : (value) => setState(() => _category = value),
                            validator: (value) => value == null
                                ? 'Selecciona un tipo de situación.'
                                : null,
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
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
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
