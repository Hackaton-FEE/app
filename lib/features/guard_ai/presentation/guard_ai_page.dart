import 'dart:async';

import '../data/sample_guard_ai_repository.dart';
import '../data/sample_guard_ai_action_executor.dart';
import 'widgets/guard_ai_action_dialog.dart';
import 'widgets/guard_ai_quick_actions.dart';

import 'package:flutter/material.dart';

import '../../../shared/presentation/status_notice.dart';
import '../domain/guard_ai_repository.dart';
import '../domain/guard_ai_action_executor.dart';
import 'guard_ai_controller.dart';
import 'widgets/guard_ai_history.dart';
import '../../cases/presentation/cases_controller.dart';
import 'widgets/guard_ai_composer.dart';
import 'widgets/guard_ai_drawer.dart';
import 'widgets/guard_ai_welcome.dart';

class GuardAiPage extends StatefulWidget {
  const GuardAiPage({
    required this.controller,
    this.casesController,
    this.createActionExecutor,
    super.key,
  });

  final GuardAiController controller;
  final CasesController? casesController;
  final GuardAiActionExecutor Function()? createActionExecutor;

  @override
  State<GuardAiPage> createState() => _GuardAiPageState();
}

class _GuardAiPageState extends State<GuardAiPage> {
  late final TextEditingController _text;
  final _inputFocus = FocusNode();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _returningHome = false;
  final _inputKey = GlobalKey();
  final _latestReplyKey = GlobalKey();
  late GuardAiConversation _conversation;
  late Widget _history;
  int? _chatId;
  bool _followReply = false;
  final _decisions = <GuardAiMessage, String>{};

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
    if (_chatId != widget.controller.chatId) {
      _followReply = false;
      _chatId = widget.controller.chatId;
      _text.text = widget.controller.draft;
    }
    _conversation = widget.controller.conversation;
    _history = GuardAiHistory(
      key: ValueKey(widget.controller.chatId),
      messages: _conversation.messages,
      decisions: _decisions,
      createActionExecutor: _conversation.isSimulation
          ? SampleGuardAiActionExecutor.new
          : widget.createActionExecutor,
      isSimulation: _conversation.isSimulation,
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
      _followReply = true;
      _text.clear();
      _inputFocus.unfocus();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (succeeded && !_followReply)) return;
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

  Future<void> _quickAction(String choice) async {
    if (choice == sampleConversationAction) {
      await widget.controller.newChat(repository: SampleGuardAiRepository());
      return;
    }
    final succeeded = await widget.controller.sendQuickPrompt(choice);
    if (!mounted) return;
    _text.text = widget.controller.draft;
    if (!succeeded) return;
    _followReply = true;
    _inputFocus.unfocus();
    final message = widget.controller.conversation.messages.last;
    if (choice == SampleGuardAiRepository.help &&
        message.recommendedAction != null) {
      final simulation = widget.controller.conversation.isSimulation;
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => GuardAiActionDialog(
          action: message.recommendedAction!,
          isSimulation: simulation,
          executor: simulation
              ? SampleGuardAiActionExecutor()
              : widget.createActionExecutor?.call(),
        ),
      );
      if (mounted && result != null) {
        _decisions[message] = result;
        setState(_updateHistory);
      }
    }
  }

  void _returnHome() {
    if (_returningHome || widget.controller.isSending) return;
    _returningHome = true;
    _scaffoldKey.currentState?.closeDrawer();
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cómo usar GuardAI'),
        scrollable: true,
        content: const Text(
          'Elige una sugerencia o escribe un mensaje para avanzar paso a paso. '
          'GuardAI te guía en la evaluación de tu privacidad y opciones de protección.\n\n'
          'Puedes abrir un formulario para registrar un caso local cuando decidas dar seguimiento a un hallazgo. '
          'Evita escribir contraseñas o datos sensibles.\n\n'
          'La conversación y lo que estés escribiendo se conservan al volver '
          'al inicio durante esta sesión de la app.',
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
          key: _scaffoldKey,
          onDrawerChanged: (open) {
            if (!open && _returningHome) {
              _returningHome = false;
              Navigator.of(context).maybePop();
            }
          },
          drawer: GuardAiDrawer(controller: controller, onHome: _returnHome),
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    controller.conversation.isSimulation
                        ? 'Muestra'
                        : 'GuardAI',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Ayuda de GuardAI',
                onPressed: controller.isSending ? null : _showHelp,
                icon: const Icon(Icons.help_outline),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      (MediaQuery.sizeOf(context).height -
                          MediaQuery.viewInsetsOf(context).bottom -
                          kToolbarHeight -
                          MediaQuery.paddingOf(context).vertical) *
                      .55,
                ),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: SingleChildScrollView(
                    key: const Key('guard-ai-composer-scroll'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: GuardAiComposer(
                          key: ValueKey((controller, controller.chatId)),
                          controller: controller,
                          casesController: widget.casesController,
                          text: _text,
                          inputFocus: _inputFocus,
                          inputKey: _inputKey,
                          onSend: _send,
                          onSuggestion: _selectSuggestion,
                          onQuickAction: _quickAction,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Listener(
                  // Manual navigation takes priority over following new replies.
                  onPointerDown: (_) => _followReply = false,
                  onPointerSignal: (_) => _followReply = false,
                  onPointerPanZoomStart: (_) => _followReply = false,
                  child: NotificationListener<ScrollMetricsNotification>(
                    onNotification: (_) {
                      if (_followReply) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final target = _latestReplyKey.currentContext;
                          if (mounted && _followReply && target != null) {
                            unawaited(Scrollable.ensureVisible(target));
                          }
                        });
                      }
                      return false;
                    },
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
                            ],
                          ),
                        ),
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

  Widget _buildHeader(BuildContext context) => Column(
    children: [
      GuardAiWelcome(
        showIntro:
            !widget.controller.isSending &&
            widget.controller.conversation.messages.isEmpty,
      ),
      if (widget.controller.isLoading)
        const StatusNotice(message: 'Abriendo GuardAI…'),
    ],
  );
}
