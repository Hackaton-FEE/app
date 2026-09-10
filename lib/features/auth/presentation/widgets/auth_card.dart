import 'package:flutter/material.dart';

import '../../../../shared/presentation/status_notice.dart';
import '../../../accounts/presentation/accounts_controller.dart';

class AuthCard extends StatefulWidget {
  const AuthCard({required this.controller, super.key});
  final AccountsController controller;

  @override
  State<AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends State<AuthCard> {
  final _label = TextEditingController();
  final _labelFocus = FocusNode();
  final _form = GlobalKey<FormState>();
  bool _registering = false;

  @override
  void dispose() {
    _label.dispose();
    _labelFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_form.currentState?.validate() ?? false)) {
      _labelFocus.requestFocus();
      return;
    }
    await widget.controller.registerWithPasskey(label: _label.text.trim());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final controller = widget.controller;
      final busy = controller.isSaving || controller.isLoading;
      return Card(
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  _registering ? 'Crear cuenta' : 'Iniciar sesión',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Usa una llave de acceso del dispositivo. El sistema te pedirá '
                'confirmar con el método de desbloqueo disponible.',
              ),
              const SizedBox(height: 16),
              if (controller.actionError != null) ...[
                StatusNotice(message: controller.actionError!, isError: true),
                const SizedBox(height: 16),
              ],
              if (_registering)
                Form(
                  key: _form,
                  child: TextFormField(
                    key: const Key('auth-label-field'),
                    controller: _label,
                    focusNode: _labelFocus,
                    enabled: !busy,
                    maxLength: 80,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la cuenta (obligatorio)',
                      helperText: 'Una etiqueta para reconocer tu cuenta.',
                      helperMaxLines: 3,
                      errorMaxLines: 3,
                    ),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Escribe un nombre para reconocer esta cuenta.'
                        : null,
                    onFieldSubmitted: (_) => busy ? null : _register(),
                  ),
                ),
              if (_registering) const SizedBox(height: 16),
              FilledButton.icon(
                key: Key(
                  _registering
                      ? 'auth-passkey-register-button'
                      : 'auth-passkey-login-button',
                ),
                onPressed: busy
                    ? null
                    : _registering
                    ? _register
                    : () => controller.signInWithPasskey(),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
                icon: const Icon(Icons.key_outlined),
                label: Text(
                  busy
                      ? 'Esperando confirmación…'
                      : _registering
                      ? 'Crear con llave de acceso'
                      : 'Entrar con llave de acceso',
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const Key('auth-mode-button'),
                onPressed: busy
                    ? null
                    : () => setState(() => _registering = !_registering),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(
                  _registering ? 'Ya tengo una cuenta' : 'Crear cuenta',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
