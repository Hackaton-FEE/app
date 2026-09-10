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

  final _loginUserController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _registerUserController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmController = TextEditingController();

  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureRegisterConfirm = true;

  @override
  void dispose() {
    _loginUserController.dispose();
    _loginPasswordController.dispose();
    _registerUserController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    await widget.controller.signIn(
      username: _loginUserController.text.trim(),
      password: _loginPasswordController.text,
    );
  }

  Future<void> _submitPasskeyLogin() async {
    await widget.controller.signInWithPasskey();
  }

  Future<void> _submitRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    await widget.controller.register(
      username: _registerUserController.text.trim(),
      password: _registerPasswordController.text,
    );
  }

  Future<void> _submitPasskeyRegister() async {
    final label = _registerUserController.text.trim().isNotEmpty
        ? _registerUserController.text.trim()
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.fingerprint_rounded,
                        color: colors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Acceso rápido con Passkey',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Entra en 1 toque. Sin contraseñas.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton(
                  key: const Key('auth-passkey-login-button'),
                  onPressed: busy ? null : _submitPasskeyLogin,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint_rounded, size: 22),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Entrar a mi Bóveda en 1 toque',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'o con nombre y contraseña',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('auth-email-field'),
            controller: _loginUserController,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Nombre o usuario',
              hintText: 'ej. Carlos Ruiz',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return 'Ingresa tu nombre o usuario.';
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
              labelText: 'Contraseña (opcional con Passkey)',
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
          OutlinedButton(
            key: const Key('auth-login-button'),
            onPressed: busy ? null : _submitLogin,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text(
                    'Iniciar sesión',
                    style: TextStyle(fontWeight: FontWeight.w600),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: colors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bóveda FIDO2 en tu dispositivo',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Llaves en hardware. Cero contraseñas.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton(
                  key: const Key('auth-passkey-register-button'),
                  onPressed: busy ? null : _submitPasskeyRegister,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_moderator_rounded, size: 22),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Crear Bóveda Segura en 1 toque',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'o personalizar nombre y credenciales',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('auth-register-email-field'),
            controller: _registerUserController,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Nombre de usuario',
              hintText: 'ej. Carlos Ruiz',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return 'Ingresa un nombre de usuario.';
              if (trimmed.length < 2) {
                return 'El nombre debe tener al menos 2 caracteres.';
              }
              if (trimmed.length > 60) {
                return 'El nombre es demasiado largo.';
              }
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
