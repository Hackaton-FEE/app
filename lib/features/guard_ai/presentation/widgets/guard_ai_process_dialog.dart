import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/palette.dart';
import '../../data/unavailable_guard_ai_action_executor.dart';
import '../../domain/guard_ai_action_executor.dart';
import '../guard_ai_process_controller.dart';
import 'guard_ai_process_timeline.dart';

/// Replaces confirmation on the same route, so completion returns to the chat.
class GuardAiProcessDialog extends StatefulWidget {
  const GuardAiProcessDialog({
    required this.action,
    this.executor,
    this.isSimulation = false,
    super.key,
  });
  final String action;
  final GuardAiActionExecutor? executor;
  final bool isSimulation;

  @override
  State<GuardAiProcessDialog> createState() => _GuardAiProcessDialogState();
}

class _GuardAiProcessDialogState extends State<GuardAiProcessDialog> {
  late final GuardAiProcessController _controller;
  Timer? _resultTimer;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _controller = GuardAiProcessController(
      action: widget.action,
      executor: widget.executor ?? UnavailableGuardAiActionExecutor(),
    )..addListener(_changed);
    unawaited(_controller.start());
  }

  bool get _finished =>
      _controller.status == GuardAiProcessStatus.completed ||
      _controller.status == GuardAiProcessStatus.failed;

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_finished && _resultTimer == null) {
      // Leave the final check/cross visible before showing the outcome popup.
      _resultTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showResult = true);
      });
    }
  }

  void _cancel() {
    _controller.cancel();
    Navigator.of(context).pop('Proceso cancelado. La acción no se completó.');
  }

  void _returnToChat() {
    final success = _controller.status == GuardAiProcessStatus.completed;
    Navigator.of(context).pop(
      success
          ? (widget.isSimulation
                ? 'Simulación completada. No se modificó ninguna cuenta.'
                : 'Acción correctamente realizada.')
          : 'No se pudo completar la acción. El proceso se detuvo.',
    );
  }

  @override
  void dispose() {
    _resultTimer?.cancel();
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        if (_finished) {
          _returnToChat();
        } else {
          _cancel();
        }
      }
    },
    child: _showResult
        ? _result()
        : AlertDialog(
            key: const Key('guard-ai-process'),
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
            title: Text(widget.isSimulation ? 'Proceso de muestra' : 'Proceso'),
            content: SizedBox(
              width: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.action,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'El estado se actualizará al confirmar cada paso.',
                  ),
                  const SizedBox(height: 24),
                  GuardAiProcessTimeline(statuses: _controller.steps),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(switch (_controller.status) {
                      GuardAiProcessStatus.failed =>
                        'El proceso se detuvo en el paso ${_controller.failedStep! + 1}.',
                      GuardAiProcessStatus.completed =>
                        'Los tres pasos se completaron.',
                      _ =>
                        'Paso ${_controller.steps.indexOf(GuardAiStepStatus.running) + 1} de 3 en curso.',
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _finished
                    ? () => setState(() => _showResult = true)
                    : _cancel,
                child: Text(_finished ? 'Ver resultado' : 'Cancelar'),
              ),
            ],
          ),
  );

  Widget _result() {
    final success = _controller.status == GuardAiProcessStatus.completed;
    return AlertDialog(
      key: Key(success ? 'guard-ai-process-success' : 'guard-ai-process-error'),
      scrollable: true,
      backgroundColor: AppPalette.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: CircleAvatar(
        radius: 28,
        backgroundColor: success
            ? AppPalette.successContainer
            : AppPalette.errorContainer,
        child: Icon(
          success ? Icons.check : Icons.close,
          color: AppPalette.deepOlive,
        ),
      ),
      title: Text(
        success
            ? (widget.isSimulation
                  ? 'Simulación completada'
                  : 'Acción correctamente realizada')
            : 'No se pudo completar la acción',
      ),
      content: Text(
        success
            ? (widget.isSimulation
                  ? 'Se completaron los pasos de muestra. No se modificó ninguna cuenta ni se envió una solicitud.'
                  : 'Se completaron los tres pasos de “${widget.action}”.')
            : 'Falló el paso “${guardAiProcessSteps[_controller.failedStep!].title}”. El proceso se detuvo y no continuó con los pasos restantes.\n\nPuedes volver al chat para revisar la recomendación.',
      ),
      actions: [
        FilledButton(
          onPressed: _returnToChat,
          child: const Text('Volver al chat'),
        ),
      ],
    );
  }
}
