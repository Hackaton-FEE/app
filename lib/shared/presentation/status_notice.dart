import 'package:flutter/material.dart';

/// Persistent feedback that does not take keyboard focus or read case content.
class StatusNotice extends StatelessWidget {
  const StatusNotice({required this.message, this.isError = false, super.key});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isError ? colors.errorContainer : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            message,
            style: TextStyle(
              color: isError
                  ? colors.onErrorContainer
                  : colors.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
