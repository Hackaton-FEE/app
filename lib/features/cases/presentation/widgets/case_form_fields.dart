import 'package:flutter/material.dart';

import '../../domain/case_input.dart';
import '../../domain/privacy_case.dart';
import '../../domain/source_link.dart';
import '../case_labels.dart';

/// The editable metadata fields; their draft and focus belong to the page.
class CaseFormFields extends StatelessWidget {
  const CaseFormFields({
    required this.titleController,
    required this.sourceUrlController,
    required this.notesController,
    required this.titleFocus,
    required this.sourceUrlFocus,
    required this.categoryFocus,
    required this.category,
    required this.onCategoryChanged,
    required this.enabled,
    super.key,
  });

  final TextEditingController titleController;
  final TextEditingController sourceUrlController;
  final TextEditingController notesController;
  final FocusNode titleFocus;
  final FocusNode sourceUrlFocus;
  final FocusNode categoryFocus;
  final CaseCategory? category;
  final ValueChanged<CaseCategory?> onCategoryChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        isRequired: true,
        child: TextFormField(
          key: const Key('case-title'),
          controller: titleController,
          focusNode: titleFocus,
          enabled: enabled,
          maxLength: CaseInput.maxTitleLength,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Título del caso',
            hintText: 'Por ejemplo: perfil que usa mi nombre',
            errorMaxLines: 5,
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Escribe un título para identificar el caso.'
              : null,
        ),
      ),
      const SizedBox(height: 12),
      Semantics(
        isRequired: true,
        child: TextFormField(
          key: const Key('case-url'),
          controller: sourceUrlController,
          focusNode: sourceUrlFocus,
          enabled: enabled,
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
          focusNode: categoryFocus,
          initialValue: category,
          isExpanded: true,
          isDense: false,
          itemHeight: null,
          decoration: const InputDecoration(
            labelText: 'Tipo de situación',
            errorMaxLines: 5,
          ),
          items: [
            for (final category in CaseCategory.values)
              DropdownMenuItem(value: category, child: Text(category.label)),
          ],
          onChanged: enabled ? onCategoryChanged : null,
          validator: (value) =>
              value == null ? 'Selecciona un tipo de situación.' : null,
        ),
      ),
      const SizedBox(height: 24),
      TextFormField(
        key: const Key('case-notes'),
        controller: notesController,
        enabled: enabled,
        maxLength: CaseInput.maxNotesLength,
        minLines: 3,
        maxLines: 6,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Notas (opcional)',
          hintText: 'Anota solo lo necesario para recordar el caso.',
        ),
      ),
    ],
  );
}
