import 'package:flutter/material.dart';

import 'help_page.dart';

/// Keep the same help entry point in each task's app bar.
class HelpButton extends StatelessWidget {
  const HelpButton({this.enabled = true, super.key});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ayuda de uso',
      icon: const Icon(Icons.help_outline),
      onPressed: enabled
          ? () => Navigator.of(context)
                .push<void>(MaterialPageRoute(builder: (_) => const HelpPage()))
          : null,
    );
  }
}
