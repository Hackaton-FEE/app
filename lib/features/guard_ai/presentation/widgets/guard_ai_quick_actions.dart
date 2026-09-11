import 'package:flutter/material.dart';

import '../../domain/guard_ai_quick_prompt.dart';

class GuardAiQuickActions extends StatelessWidget {
  const GuardAiQuickActions({
    required this.enabled,
    required this.onSelected,
    super.key,
  });

  final bool enabled;
  final ValueChanged<String> onSelected;

  Future<void> _open(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Acciones rápidas',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Elige una opción. Tu borrador se conserva.'),
              for (final option in [
                (
                  GuardAiQuickPrompt.review,
                  Icons.person_search_outlined,
                  'Análisis y orientación sobre el perfil.',
                ),
                (
                  GuardAiQuickPrompt.help,
                  Icons.task_alt,
                  'Revisar una acción, aceptarla o posponerla.',
                ),
                (
                  GuardAiQuickPrompt.plan,
                  Icons.checklist,
                  'Organizar los siguientes pasos en la app.',
                ),
              ])
                ListTile(
                  leading: Icon(option.$2),
                  title: Text(option.$1),
                  subtitle: Text(option.$3),
                  onTap: () => Navigator.pop(context, option.$1),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver al chat'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice != null && context.mounted) onSelected(choice);
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('guard-ai-quick-actions'),
    tooltip: 'Acciones rápidas',
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    onPressed: enabled ? () => _open(context) : null,
    icon: const Icon(Icons.bolt_outlined),
  );
}
