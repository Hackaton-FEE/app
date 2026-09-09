import 'package:flutter/material.dart';

import '../../domain/guard_ai_repository.dart';

/// Keeps earlier turns lazy and the latest reply mounted for scroll recovery.
class GuardAiHistory extends StatelessWidget {
  const GuardAiHistory({
    required this.messages,
    required this.latestReplyKey,
    super.key,
  });

  final List<GuardAiMessage> messages;
  final GlobalKey latestReplyKey;

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
            ),
          ),
        ),
    ],
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, super.key});

  final GuardAiMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fromPerson = message.role == GuardAiRole.person;
    final author = fromPerson ? 'Tú' : 'GuardAI';
    return Semantics(
      container: true,
      label: '$author: ${message.text}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fromPerson
              ? colors.primaryContainer
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: fromPerson
                      ? colors.onPrimaryContainer
                      : colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message.text,
                style: TextStyle(
                  color: fromPerson
                      ? colors.onPrimaryContainer
                      : colors.onSurface,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
