import 'package:flutter/material.dart';

import '../../app/palette.dart';

/// Persistent feedback that does not take keyboard focus or read case content.
class StatusNotice extends StatelessWidget {
  const StatusNotice({
    required this.message,
    this.isError = false,
    this.isSuccess = false,
    super.key,
  });

  final String message;
  final bool isError;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isError
              ? AppPalette.errorContainer
              : isSuccess
              ? AppPalette.successContainer
              : colors.primaryContainer,
          border: isError || isSuccess
              ? Border.all(
                  color: isError ? AppPalette.error : AppPalette.success,
                )
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            message,
            style: TextStyle(
              color: isError || isSuccess
                  ? AppPalette.textPrimary
                  : colors.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
