import 'package:flutter/material.dart';

import '../../auth/presentation/widgets/auth_card.dart';
import 'accounts_controller.dart';
import 'widgets/account_product_overview.dart';

class AccountPickerPage extends StatefulWidget {
  const AccountPickerPage({required this.controller, super.key});

  final AccountsController controller;

  @override
  State<AccountPickerPage> createState() => _AccountPickerPageState();
}

class _AccountPickerPageState extends State<AccountPickerPage> {
  final _marketing = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Osisn't",
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListenableBuilder(
              listenable: widget.controller,
              child: AccountProductOverview(firstPanelKey: _marketing),
              builder: (context, productOverview) {
                final controller = widget.controller;
                final busy = controller.isLoading || controller.isSaving;
                return SingleChildScrollView(
                  key: const Key('account-picker-scroll'),
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    32 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ExcludeSemantics(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              Icons.fingerprint_rounded,
                              size: 38,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        header: true,
                        child: Text(
                          'Elige tu cuenta',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tu espacio para entender y cuidar tu huella digital.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      if (controller.isLoading)
                        Semantics(
                          liveRegion: true,
                          label: 'Cargando cuentas',
                          child: const LinearProgressIndicator(),
                        )
                      else if (controller.loadError != null)
                        _AccountError(
                          message: controller.loadError!,
                          onRetry: controller.load,
                        )
                      else ...[
                        if (controller.authRepository != null) ...[
                          AuthCard(controller: controller),
                          const SizedBox(height: 16),
                          Divider(
                            color: colors.outlineVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'O continúa con tu cuenta local',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (controller.accounts.isEmpty &&
                            controller.authRepository == null)
                          _AccountError(
                            message:
                                'La cuenta no está disponible. Intenta cargarla de nuevo.',
                            onRetry: controller.load,
                          ),
                        for (final account in controller.accounts)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: OutlinedButton(
                              key: ValueKey('account-${account.id}'),
                              onPressed: busy
                                  ? null
                                  : () => controller.selectAccount(account),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                backgroundColor: colors.surface,
                              ),
                              child: Row(
                                children: [
                                  ExcludeSemantics(
                                    child: CircleAvatar(
                                      backgroundColor: colors.primaryContainer,
                                      foregroundColor:
                                          colors.onPrimaryContainer,
                                      child: Text(
                                        account.name.characters.first
                                            .toUpperCase(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          account.name,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          account.email,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Acceso rápido configurado en este dispositivo. Entra directamente con un toque.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextButton.icon(
                        onPressed: () => Scrollable.ensureVisible(
                          _marketing.currentContext!,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 52),
                        ),
                        icon: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 18,
                        ),
                        label: const Text("Descubre Osisn't"),
                      ),
                      const SizedBox(height: 32),
                      productOverview!,
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountError extends StatelessWidget {
  const _AccountError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(liveRegion: true, child: Text(message)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
