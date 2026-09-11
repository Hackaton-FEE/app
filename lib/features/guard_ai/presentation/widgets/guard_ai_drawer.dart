import 'package:flutter/material.dart';

import '../../../../app/palette.dart';
import '../guard_ai_controller.dart';

class GuardAiDrawer extends StatelessWidget {
  const GuardAiDrawer({
    required this.controller,
    required this.onHome,
    super.key,
  });
  final GuardAiController controller;
  final VoidCallback onHome;

  Future<void> _delete(BuildContext context, int id, String title) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('¿Eliminar conversación?'),
        content: Text(
          'Se eliminará “$title” del historial de esta sesión. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.error,
              foregroundColor: AppPalette.black,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (accepted == true) await controller.deleteChat(id);
  }

  @override
  Widget build(BuildContext context) {
    final busy = controller.isSending || controller.isLoading;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppPalette.deepOlive,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 32,
                    color: AppPalette.paleCream,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'GuardAI',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.paleCream,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tu espacio de privacidad',
                    style: TextStyle(color: AppPalette.paleCream),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Regresar al inicio'),
              enabled: !busy,
              onTap: onHome,
            ),
            ListTile(
              leading: const Icon(Icons.add_comment_outlined),
              title: const Text('Nueva conversación'),
              enabled: !busy,
              onTap: () {
                Navigator.pop(context);
                controller.newChat();
              },
            ),
            ExpansionTile(
              initiallyExpanded: true,
              leading: const Icon(Icons.history),
              title: const Text('Historial'),
              children: [
                for (final entry in controller.chats.entries)
                  ListTile(
                    selected: entry.key == controller.chatId,
                    selectedTileColor: AppPalette.paleCream,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(
                      entry.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    enabled: !busy,
                    onTap: () {
                      controller.selectChat(entry.key);
                      Navigator.pop(context);
                    },
                    trailing: IconButton(
                      tooltip: 'Eliminar ${entry.value}',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: busy
                          ? null
                          : () => _delete(context, entry.key, entry.value),
                    ),
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('El historial se conserva solo durante esta sesión.'),
            ),
          ],
        ),
      ),
    );
  }
}
