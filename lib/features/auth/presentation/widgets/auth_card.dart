import 'package:flutter/material.dart';

import '../../../accounts/presentation/accounts_controller.dart';

class AuthCard extends StatefulWidget {
  const AuthCard({required this.controller, super.key});

  final AccountsController controller;

  @override
  State<AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends State<AuthCard> {
  int _selectedTab = 0; // 0: Login, 1: Registro

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmController = TextEditingController();

  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureRegisterConfirm = true;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    await widget.controller.signIn(
      email: _loginEmailController.text.trim(),
      password: _loginPasswordController.text,
    );
  }

  Future<void> _submitPasskeyLogin() async {
    await widget.controller.signInWithPasskey();
  }

  Future<void> _submitRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    await widget.controller.register(
      email: _registerEmailController.text.trim(),
      password: _registerPasswordController.text,
    );
  }

  Future<void> _submitPasskeyRegister() async {
    final label = _registerEmailController.text.trim().isNotEmpty
        ? _registerEmailController.text.trim()
        : 'Mi Bóveda FEE';
    await widget.controller.registerWithPasskey(label: label);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final busy = widget.controller.isSaving || widget.controller.isLoading;
    final actionError = widget.controller.actionError;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  label: Text('Iniciar sesión'),
                  icon: Icon(Icons.login_rounded),
                ),
                ButtonSegment<int>(
                  value: 1,
                  label: Text('Crear cuenta'),
                  icon: Icon(Icons.person_add_outlined),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: busy
                  ? null
                  : (set) => setState(() => _selectedTab = set.first),
            ),
            const SizedBox(height: 20),
            if (actionError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: colors.onErrorContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          actionError,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_selectedTab == 0)
              _buildLoginForm(theme, colors, busy)
            else
              _buildRegisterForm(theme, colors, busy),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(ThemeData theme, ColorScheme colors, bool busy) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            key: const Key('auth-passkey-login-button'),
            onPressed: busy ? null : _submitPasskeyLogin,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fingerprint_rounded),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Acceder con Passkey',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'o con credenciales',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const Key('auth-email-field'),
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'usuario@correo.com',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return 'Ingresa tu correo.';
              if (!trimmed.contains('@') || !trimmed.contains('.')) {
                return 'Ingresa un correo electrónico válido.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('auth-password-field'),
            controller: _loginPasswordController,
            obscureText: _obscureLoginPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitLogin(),
            enabled: !busy,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _obscureLoginPassword
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
                icon: Icon(
                  _obscureLoginPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(
                  () => _obscureLoginPassword = !_obscureLoginPassword,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa tu contraseña.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('auth-login-button'),
            onPressed: busy ? null : _submitLogin,
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Iniciar sesión',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(ThemeData theme, ColorScheme colors, bool busy) {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            key: const Key('auth-passkey-register-button'),
            onPressed: busy ? null : _submitPasskeyRegister,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fingerprint_rounded),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Crear Bóveda con Passkey',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'o con credenciales',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const Key('auth-register-email-field'),
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'usuario@correo.com',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return 'Ingresa un correo electrónico.';
              if (!trimmed.contains('@') || !trimmed.contains('.')) {
                return 'Ingresa un correo electrónico válido.';
              }
              if (trimmed.length > 254) return 'El correo es demasiado largo.';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('auth-register-password-field'),
            controller: _registerPasswordController,
            obscureText: _obscureRegisterPassword,
            textInputAction: TextInputAction.next,
            enabled: !busy,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              helperText: 'Mínimo 12 caracteres (12–128)',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _obscureRegisterPassword
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
                icon: Icon(
                  _obscureRegisterPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(
                  () => _obscureRegisterPassword = !_obscureRegisterPassword,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 12 || value.length > 128) {
                return 'La contraseña debe tener entre 12 y 128 caracteres.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('auth-register-confirm-password-field'),
            controller: _registerConfirmController,
            obscureText: _obscureRegisterConfirm,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitRegister(),
            enabled: !busy,
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: const Icon(Icons.lock_reset_rounded),
              suffixIcon: IconButton(
                tooltip: _obscureRegisterConfirm
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
                icon: Icon(
                  _obscureRegisterConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(
                  () => _obscureRegisterConfirm = !_obscureRegisterConfirm,
                ),
              ),
            ),
            validator: (value) {
              if (value != _registerPasswordController.text) {
                return 'Las contraseñas no coinciden.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('auth-register-button'),
            onPressed: busy ? null : _submitRegister,
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Crear cuenta e ingresar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}
