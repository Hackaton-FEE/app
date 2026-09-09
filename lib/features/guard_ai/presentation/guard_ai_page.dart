import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/presentation/status_notice.dart';
import '../domain/guard_ai_repository.dart';
import 'guard_ai_controller.dart';
import 'widgets/guard_ai_history.dart';

class GuardAiPage extends StatefulWidget {
  const GuardAiPage({required this.controller, super.key});

  final GuardAiController controller;

  @override
  State<GuardAiPage> createState() => _GuardAiPageState();
}

class _GuardAiPageState extends State<GuardAiPage> {
  late final TextEditingController _text;
  final _inputFocus = FocusNode();
  final _inputKey = GlobalKey();
  final _latestReplyKey = GlobalKey();
  late GuardAiConversation _conversation;
  late Widget _history;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.controller.draft);
    _updateHistory();
    widget.controller.addListener(_onControllerChanged);
    unawaited(widget.controller.load());
  }

  @override
  void didUpdateWidget(covariant GuardAiPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onControllerChanged);
    _text.text = widget.controller.draft;
    _updateHistory();
    widget.controller.addListener(_onControllerChanged);
    unawaited(widget.controller.load());
  }

  void _onControllerChanged() {
    if (identical(_conversation, widget.controller.conversation)) return;
    setState(_updateHistory);
  }

  void _updateHistory() {
    _conversation = widget.controller.conversation;
    _history = GuardAiHistory(
      messages: _conversation.messages,
      latestReplyKey: _latestReplyKey,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _text.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (widget.controller.isSending) return;
    final succeeded = await widget.controller.sendDraft();
    if (!mounted) return;
    if (succeeded) {
      _text.clear();
      _inputFocus.unfocus();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!succeeded) _inputFocus.requestFocus();
      final target = succeeded
          ? _latestReplyKey.currentContext
          : _inputKey.currentContext;
      if (target != null) {
        unawaited(Scrollable.ensureVisible(target));
      }
    });
  }

  void _selectSuggestion(String suggestion) {
    if (widget.controller.isSending) return;
    widget.controller.setDraft(suggestion);
    _text.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    unawaited(_send());
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cómo usar GuardAI'),
        scrollable: true,
        content: const Text(
          'Elige una sugerencia o escribe un mensaje para avanzar paso a paso. '
          'Las respuestas de esta versión son ejemplos predefinidos: todavía '
          'no hay una IA conectada.\n\n'
          'El chat no consulta sitios, no crea casos y no envía información. '
          'Evita escribir contraseñas o datos sensibles.\n\n'
          'La conversación y lo que estés escribiendo se conservan al volver '
          'al inicio durante esta sesión de la app. Se pierden al cerrar '
          'por completo la aplicación.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver al chat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    child: _history,
    builder: (context, history) {
      final controller = widget.controller;
      return PopScope(
        canPop: !controller.isSending,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('GuardAI'),
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const BackButtonIcon(),
              onPressed: controller.isSending
                  ? null
                  : () => Navigator.of(context).maybePop(),
            ),
            actions: [
              IconButton(
                tooltip: 'Ayuda de GuardAI',
                onPressed: controller.isSending ? null : _showHelp,
                icon: const Icon(Icons.help_outline),
              ),
            ],
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: CustomScrollView(
                  key: const Key('guard-ai-scroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          SliverToBoxAdapter(child: _buildHeader(context)),
                          history!,
                          SliverToBoxAdapter(child: _buildComposer()),
                        ],
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

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Tu privacidad, paso a paso',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Demostración local · Respuestas predefinidas, '
              'sin IA conectada ni envíos. El chat dura '
              'esta sesión de la app.',
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (widget.controller.isLoading)
          const StatusNotice(message: 'Abriendo GuardAI…'),
      ],
    );
  }

  Widget _buildComposer() {
    final controller = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.error != null) ...[
          StatusNotice(
            key: const Key('guard-ai-error'),
            message: controller.error!,
            isError: true,
          ),
          const SizedBox(height: 12),
        ] else if (controller.status != null) ...[
          StatusNotice(message: controller.status!),
          const SizedBox(height: 12),
        ],
        if (!controller.isReady && !controller.isLoading)
          OutlinedButton.icon(
            onPressed: controller.load,
            icon: const Icon(Icons.refresh),
            label: const Text('Volver a abrir el chat'),
          ),
        if (controller.isReady) ...[
          for (final suggestion
              in controller.draft.isEmpty
                  ? controller.conversation.suggestions
                  : const <String>[])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: controller.isSending
                    ? null
                    : () => _selectSuggestion(suggestion),
                child: Text(suggestion),
              ),
            ),
          const SizedBox(height: 16),
          Semantics(
            isRequired: true,
            child: TextField(
              key: _inputKey,
              controller: _text,
              focusNode: _inputFocus,
              enabled: !controller.isSending,
              onChanged: controller.setDraft,
              minLines: 2,
              maxLines: 5,
              maxLength: GuardAiInput.maxLength,
              maxLengthEnforcement: MaxLengthEnforcement.none,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Mensaje para GuardAI',
                errorText: controller.error,
                errorMaxLines: 8,
                helperText:
                    'El mensaje es obligatorio para continuar. '
                    'Evita datos sensibles.',
                helperMaxLines: 6,
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('guard-ai-send'),
            onPressed: controller.isSending ? null : _send,
            icon: Icon(
              controller.isSending ? Icons.hourglass_top : Icons.arrow_upward,
            ),
            label: Text(
              controller.isSending ? 'Preparando respuesta…' : 'Enviar mensaje',
            ),
          ),
        ],
      ],
    );
  }
}
