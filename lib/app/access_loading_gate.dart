import 'package:flutter/material.dart';

/// Espera recuperable para preparar acceso o cargar identidad persistida.
class AccessLoadingGate extends StatelessWidget {
  const AccessLoadingGate({
    required this.error,
    required this.onRetry,
    this.onSignOut,
    this.keyPrefix = 'identity-profile',
    this.loadingText = 'Preparando tu perfil…',
    super.key,
  });
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onSignOut;
  final String keyPrefix;
  final String loadingText;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error == null) ...[
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 24),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      loadingText,
                      key: Key('$keyPrefix-loading'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(error!, key: Key('$keyPrefix-error')),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tus datos guardados se conservan. Reintenta para continuar.',
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: Key('$keyPrefix-retry'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: onRetry,
                    child: const Text('Reintentar'),
                  ),
                ],
                if (onSignOut != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: Key('$keyPrefix-sign-out'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: onSignOut,
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
