import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/palette.dart';
import '../../domain/guard_ai_action_executor.dart';
import 'guard_ai_process_dialog.dart';

/// A local decision only: no external action or notification is scheduled.
class GuardAiActionDialog extends StatefulWidget {
  const GuardAiActionDialog({required this.action, this.executor, super.key});
  final String action;
  final GuardAiActionExecutor? executor;

  @override
  State<GuardAiActionDialog> createState() => _GuardAiActionDialogState();
}

class _GuardAiActionDialogState extends State<GuardAiActionDialog> {
  final _form = GlobalKey<FormState>();
  final _time = TextEditingController(text: '3');
  final _timeFocus = FocusNode();
  bool _postponing = false;
  bool _processing = false;
  String _unit = 'días';

  @override
  void dispose() {
    _time.dispose();
    _timeFocus.dispose();
    super.dispose();
  }

  void _finish(String result) => Navigator.of(context).pop(result);

  void _postpone() {
    if (!_form.currentState!.validate()) {
      _timeFocus.requestFocus();
      return;
    }
    _finish(
      'Preferencia: avisar en ${int.parse(_time.text)} $_unit. '
      'No hay una notificación programada.',
    );
  }

  @override
  Widget build(BuildContext context) => _processing
      ? GuardAiProcessDialog(action: widget.action, executor: widget.executor)
      : AlertDialog(
          scrollable: true,
          backgroundColor: AppPalette.card,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    tooltip: _postponing
                        ? 'Regresar a la recomendación'
                        : 'Cerrar recomendación',
                    onPressed: _postponing
                        ? () => setState(() => _postponing = false)
                        : () => Navigator.of(context).pop(),
                    icon: Icon(_postponing ? Icons.arrow_back : Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(_postponing ? 'Recordatorio' : 'Confirmar acción'),
            ],
          ),
          content: _postponing
              ? Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(widget.action),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _time,
                        focusNode: _timeFocus,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Avisar en',
                          helperText: 'De 1 a 365',
                          errorMaxLines: 3,
                        ),
                        validator: (value) {
                          final amount = int.tryParse(value ?? '');
                          return amount == null || amount < 1 || amount > 365
                              ? 'Escribe un número entre 1 y 365.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Unidad de tiempo',
                        ),
                        items: [
                          for (final unit in ['horas', 'días', 'semanas'])
                            DropdownMenuItem(value: unit, child: Text(unit)),
                        ],
                        onChanged: (value) => setState(() => _unit = value!),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'La programación de notificaciones aún no está disponible.',
                      ),
                    ],
                  ),
                )
              : Text(
                  '¿Quieres realizar ${widget.action}?\n\n'
                  'La acción necesita un servicio de ejecución conectado.',
                ),
          actions: [
            IntrinsicHeight(
              child: Row(
                key: const Key('guard-ai-decision-row'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _decision(
                    'Aceptar',
                    Icons.check,
                    AppPalette.successContainer,
                    _postponing
                        ? _postpone
                        : () => setState(() => _processing = true),
                    tooltip: _postponing ? 'Aceptar recordatorio' : 'Aceptar',
                  ),
                  const SizedBox(width: 8),
                  _decision(
                    'Rechazar',
                    Icons.close,
                    AppPalette.errorContainer,
                    () => _finish(
                      'Recomendación rechazada. Puedes revisarla después.',
                    ),
                  ),
                  if (!_postponing) ...[
                    const SizedBox(width: 8),
                    _decision(
                      'Posponer',
                      Icons.schedule,
                      AppPalette.scaffold,
                      () => setState(() => _postponing = true),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );

  Widget _decision(
    String label,
    IconData icon,
    Color background,
    VoidCallback onTap, {
    String? tooltip,
  }) => Expanded(
    child: Tooltip(
      message: tooltip ?? label,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: AppPalette.deepOlive,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          minimumSize: const Size(48, 72),
        ),
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
