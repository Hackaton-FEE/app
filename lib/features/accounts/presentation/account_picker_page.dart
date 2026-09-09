import 'package:flutter/material.dart';

import '../../help/presentation/help_button.dart';
import 'accounts_controller.dart';

class AccountPickerPage extends StatefulWidget {
  const AccountPickerPage({required this.controller, super.key});

  final AccountsController controller;

  @override
  State<AccountPickerPage> createState() => _AccountPickerPageState();
}

class _AccountPickerPageState extends State<AccountPickerPage> {
  final _marketing = GlobalKey();

  Future<void> _addDemoAccount() async {
    final number = widget.controller.accounts.length + 1;
    await widget.controller.addAccount(
      name: 'Cuenta de ejemplo $number',
      email: 'demo.$number@example.invalid',
    );
  }

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
        actions: const [HelpButton(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
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
                        if (controller.accounts.isEmpty) ...[
                          const Text(
                            'Aún no tienes cuentas. Crea una para comenzar.',
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            key: const Key('account-create'),
                            onPressed: busy ? null : _addDemoAccount,
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: const Text('Crear una cuenta'),
                          ),
                        ],
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
                        const SizedBox(height: 4),
                        TextButton.icon(
                          key: const Key('account-add-existing'),
                          onPressed: busy ? null : _addDemoAccount,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 52),
                          ),
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: Text(
                            busy ? 'Preparando cuenta…' : 'Usar otra cuenta',
                          ),
                        ),
                        if (controller.actionError != null)
                          _AccountError(
                            message: controller.actionError!,
                            onRetry: _addDemoAccount,
                          ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Vista previa con cuentas de ejemplo. Entra con un toque, sin contraseña.',
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
                      Container(
                        key: _marketing,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          key: const Key('account-marketing'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TU VIDA DIGITAL, CON PERSPECTIVA',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onPrimary,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Semantics(
                              header: true,
                              child: Text(
                                'Menos dudas.\nMás control.',
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  color: colors.onPrimary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Lo que compartes cuenta una historia. Explora tu huella, entiende lo que ves y encuentra tu siguiente paso.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colors.onPrimary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ExcludeSemantics(
                              child: Icon(
                                Icons.hub_outlined,
                                size: 64,
                                color: colors.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      Semantics(
                        header: true,
                        child: Text(
                          'Así funciona',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _FeatureStep(
                        number: '01',
                        title: 'Explora tu huella',
                        body: 'Recorre un mapa de perfiles, datos de contacto y otras señales de tu presencia en internet.',
                      ),
                      const _FeatureStep(
                        number: '02',
                        title: 'Dale contexto con GuardAI',
                        body: 'Empieza una conversación. Pregunta, responde y aclara qué quieres revisar, paso a paso.',
                      ),
                      const _FeatureStep(
                        number: '03',
                        title: 'Decide cómo seguir',
                        body: 'Ordena tus dudas y conoce posibles acciones para cuidar lo que compartes.',
                      ),
                      const SizedBox(height: 8),
                      Card(
                        color: colors.surfaceContainerLow,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.auto_awesome_outlined,
                                color: colors.primary,
                                size: 28,
                              ),
                              const SizedBox(height: 16),
                              Semantics(
                                header: true,
                                child: Text(
                                  'Conoce a GuardAI',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Una conversación para empezar a entender. Sin tener todas las respuestas desde el primer mensaje.',
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'En esta vista previa, el análisis y las respuestas son ejemplos locales. No se consultan sitios externos ni se envían solicitudes.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'A tu ritmo. Desde un solo lugar.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
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

class _FeatureStep extends StatelessWidget {
  const _FeatureStep({
    required this.number,
    required this.title,
    required this.body,
  });
  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(
            number,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Text(body),
            ],
          ),
        ),
      ],
    ),
  );
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
