import 'package:flutter/material.dart';

import '../../domain/guard_ai_repository.dart';
import '../../domain/guard_ai_action_executor.dart';
import 'guard_ai_action_dialog.dart';
import 'guard_ai_profile_report_card.dart';

/// Keeps earlier turns lazy and the latest reply mounted for scroll recovery.
class GuardAiHistory extends StatelessWidget {
  const GuardAiHistory({
    required this.messages,
    required this.latestReplyKey,
    this.decisions,
    this.createActionExecutor,
    super.key,
  });

  final List<GuardAiMessage> messages;
  final GlobalKey latestReplyKey;
  final Map<GuardAiMessage, String>? decisions;
  final GuardAiActionExecutor Function()? createActionExecutor;

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: [
      SliverList.builder(
        itemCount: messages.isEmpty ? 0 : messages.length - 1,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _MessageBubble(
            key: ValueKey('guard-ai-message-$index'),
            message: messages[index],
            decisions: decisions,
            createActionExecutor: createActionExecutor,
          ),
        ),
      ),
      if (messages.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            key: latestReplyKey,
            padding: const EdgeInsets.only(bottom: 16),
            child: _MessageBubble(
              key: ValueKey('guard-ai-message-${messages.length - 1}'),
              message: messages.last,
              decisions: decisions,
              createActionExecutor: createActionExecutor,
            ),
          ),
        ),
    ],
  );
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.message,
    this.decisions,
    this.createActionExecutor,
    super.key,
  });

  final GuardAiMessage message;
  final Map<GuardAiMessage, String>? decisions;
  final GuardAiActionExecutor Function()? createActionExecutor;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  String? _decision;

  Future<void> _recommendation() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => GuardAiActionDialog(
        action: widget.message.recommendedAction!,
        executor: widget.createActionExecutor?.call(),
      ),
    );
    if (mounted && result != null) {
      widget.decisions?[widget.message] = result;
      setState(() => _decision = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final decision = widget.decisions?[message] ?? _decision;
    final colors = Theme.of(context).colorScheme;
    final fromPerson = message.role == GuardAiRole.person;
    final author = fromPerson ? 'Tú' : 'GuardAI';
    return Align(
      alignment: fromPerson ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: .92,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fromPerson ? colors.primary : colors.surface,
            border: fromPerson
                ? null
                : Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(fromPerson ? 22 : 6),
              bottomRight: Radius.circular(fromPerson ? 6 : 22),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!fromPerson) ...[
                      Icon(Icons.auto_awesome, size: 16, color: colors.primary),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      author,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: fromPerson ? colors.onPrimary : colors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (message.profileReport != null)
                  GuardAiProfileReportCard(report: message.profileReport!)
                else
                  Text(
                    message.text,
                    style: TextStyle(
                      color: fromPerson ? colors.onPrimary : colors.onSurface,
                      height: 1.5,
                    ),
                  ),
                if (message.recommendedAction != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _recommendation,
                    icon: const Icon(Icons.task_alt),
                    label: Text(message.recommendedAction!),
                  ),
                  if (decision != null)
                    Semantics(liveRegion: true, child: Text(decision)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
