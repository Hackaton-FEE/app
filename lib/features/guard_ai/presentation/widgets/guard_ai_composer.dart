import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/palette.dart';
import '../../../../shared/presentation/status_notice.dart';
import '../../../cases/presentation/cases_controller.dart';
import '../../domain/guard_ai_repository.dart';
import '../guard_ai_controller.dart';
import 'report_prompt.dart';
import 'guard_ai_thinking.dart';

class GuardAiComposer extends StatefulWidget {
  const GuardAiComposer({
    required this.controller,
    required this.text,
    required this.inputFocus,
    required this.inputKey,
    required this.onSend,
    required this.onSuggestion,
    this.casesController,
    super.key,
  });
  final GuardAiController controller;
  final CasesController? casesController;
  final TextEditingController text;
  final FocusNode inputFocus;
  final GlobalKey inputKey;
  final VoidCallback onSend;
  final ValueChanged<String> onSuggestion;

  @override
  State<GuardAiComposer> createState() => _GuardAiComposerState();
}

class _GuardAiComposerState extends State<GuardAiComposer> {
  bool _suggestionsVisible = false;

  void _send() {
    setState(() => _suggestionsVisible = false);
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.error != null) ...[
          StatusNotice(
            key: const Key('guard-ai-error'),
            message: controller.error!,
            isError: true,
          ),
          const SizedBox(height: 12),
        ],
        if (!controller.isReady && !controller.isLoading)
          OutlinedButton.icon(
            onPressed: controller.load,
            icon: const Icon(Icons.refresh),
            label: const Text('Volver a abrir el chat'),
          ),
        if (controller.isReady) ...[
          if (controller.conversation.canPrepareReport &&
              widget.casesController != null)
            ReportPrompt(
              controller: widget.casesController!,
              enabled: !controller.isSending,
            ),
          if (_suggestionsVisible)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  for (final suggestion in controller.conversation.suggestions)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 192,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: suggestion == 'Revisar mi perfil'
                                ? AppPalette.paleCream
                                : AppPalette.scaffold,
                            side: BorderSide(
                              color: suggestion == 'Revisar mi perfil'
                                  ? AppPalette.sandGold
                                  : AppPalette.cardBorder,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onPressed: controller.isSending
                              ? null
                              : () {
                                  setState(() => _suggestionsVisible = false);
                                  widget.onSuggestion(suggestion);
                                },
                          child: Text(suggestion),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (controller.isSending) const GuardAiThinking(),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppPalette.scaffold,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppPalette.cardBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Semantics(
                      isRequired: true,
                      label: 'Mensaje para GuardAI',
                      child: TextField(
                        key: widget.inputKey,
                        controller: widget.text,
                        focusNode: widget.inputFocus,
                        enabled: !controller.isSending,
                        onChanged: (value) {
                          controller.setDraft(value);
                          if (_suggestionsVisible) {
                            setState(() => _suggestionsVisible = false);
                          }
                        },
                        minLines: 1,
                        maxLines: 4,
                        maxLength: GuardAiInput.maxLength,
                        maxLengthEnforcement: MaxLengthEnforcement.none,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Mensaje para GuardAI',
                          hintStyle: TextStyle(fontSize: 14),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (controller.conversation.suggestions.isNotEmpty)
                    IconButton(
                      tooltip: _suggestionsVisible
                          ? 'Ocultar sugerencias'
                          : 'Mostrar sugerencias',
                      isSelected: _suggestionsVisible,
                      onPressed: controller.isSending
                          ? null
                          : () => setState(
                              () => _suggestionsVisible = !_suggestionsVisible,
                            ),
                      icon: const Icon(Icons.help_outline, size: 22),
                    ),
                  IconButton.filled(
                    key: const Key('guard-ai-send'),
                    tooltip: controller.isSending
                        ? 'Thinking…'
                        : 'Enviar mensaje',
                    onPressed: controller.isSending ? null : _send,
                    icon: Icon(
                      controller.isSending
                          ? Icons.hourglass_top
                          : Icons.arrow_upward,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
