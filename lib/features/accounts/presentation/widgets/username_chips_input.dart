import 'package:flutter/material.dart';

/// An input field and chip list to manage social usernames and handles.
class UsernameChipsInput extends StatefulWidget {
  const UsernameChipsInput({
    required this.usernames,
    required this.onChanged,
    super.key,
  });

  final List<String> usernames;
  final ValueChanged<List<String>> onChanged;

  @override
  State<UsernameChipsInput> createState() => _UsernameChipsInputState();
}

class _UsernameChipsInputState extends State<UsernameChipsInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim().replaceAll('@', '');
    if (text.isNotEmpty && !widget.usernames.contains(text)) {
      widget.onChanged([...widget.usernames, text]);
      _controller.clear();
    }
  }

  void _remove(int index) {
    final updated = [...widget.usernames]..removeAt(index);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nombres de usuario o alias (Redes y plataformas)',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Ej. jdoe, pepito_dev',
                  prefixText: '@ ',
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: _add,
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        if (widget.usernames.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < widget.usernames.length; i++)
                InputChip(
                  label: Text('@${widget.usernames[i]}'),
                  onDeleted: () => _remove(i),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
