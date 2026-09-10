import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/palette.dart';
import '../../../core/widgets/app_logo.dart';
import '../../footprint/presentation/footprint_controller.dart';
import '../domain/identity_profile.dart';
import '../domain/local_account.dart';
import 'identity_profile_controller.dart';
import 'widgets/username_chips_input.dart';

/// Screen to setup or edit the target identity profile used for OSINT audits.
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({
    required this.account,
    required this.identityController,
    this.footprintController,
    this.isInitialOnboarding = true,
    this.onCompleted,
    super.key,
  });

  final LocalAccount account;
  final IdentityProfileController identityController;
  final FootprintController? footprintController;
  final bool isInitialOnboarding;
  final VoidCallback? onCompleted;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _identifierController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  List<String> _associatedUsernames = [];
  bool _consentSelfAudit = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final profile = widget.identityController.profile;
    final initialId = profile?.mainIdentifier.isNotEmpty == true
        ? profile!.mainIdentifier
        : widget.account.email;
    final initialName = profile?.fullName ?? '';

    _identifierController = TextEditingController(text: initialId);
    _nameController = TextEditingController(text: initialName);
    _phoneController = TextEditingController(text: profile?.phone ?? '');
    if (profile != null) {
      _associatedUsernames = List.of(profile.associatedUsernames);
      _consentSelfAudit = profile.consentSelfAudit;
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitAndStart() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consentSelfAudit) {
      setState(() {
        _errorMessage =
            'Debes autorizar la auto-auditoría ética para continuar.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final mainId = _identifierController.text.trim();
    final fullName = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    final profile = IdentityProfile(
      accountId: widget.account.id,
      mainIdentifier: mainId,
      fullName: fullName.isNotEmpty ? fullName : null,
      associatedUsernames: _associatedUsernames,
      associatedEmail: mainId.contains('@') ? mainId : null,
      phone: phone.isNotEmpty ? phone : null,
      consentSelfAudit: _consentSelfAudit,
      hasCompletedOnboarding: true,
      createdAt: widget.identityController.profile?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await widget.identityController.save(profile);
    if (!mounted) return;

    if (!success) {
      setState(() {
        _isSubmitting = false;
        _errorMessage =
            widget.identityController.error ?? 'Error al guardar el perfil.';
      });
      return;
    }

    if (widget.footprintController != null) {
      unawaited(
        widget.footprintController!.scanIdentity(
          profile.mainIdentifier,
          associatedUsernames: profile.associatedUsernames,
          consentSelfAudit: profile.consentSelfAudit,
        ),
      );
    }

    widget.onCompleted?.call();
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (!widget.isInitialOnboarding) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _skip() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final saved = await widget.identityController.skipOnboarding(
      identifier: _identifierController.text.trim(),
    );
    if (!mounted) return;
    if (!saved) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = widget.identityController.error;
      });
      return;
    }
    widget.onCompleted?.call();
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isInitialOnboarding
              ? 'Perfil de Auditoría'
              : 'Editar Identidad',
        ),
        automaticallyImplyLeading: !widget.isInitialOnboarding,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                children: [
                  const Center(child: AppLogo(size: 52)),
                  const SizedBox(height: 16),
                  Text(
                    widget.isInitialOnboarding
                        ? 'Configura tu identidad a proteger'
                        : 'Identidad objetivo monitoreada',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Define qué datos personales rastreará Osisn\'t en fuentes públicas y filtraciones para salvaguardar tu privacidad.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _identifierController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre o identificador principal *',
                      helperText: 'Tu nombre, alias o identificador más utilizado en tus cuentas.',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    keyboardType: TextInputType.text,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'El identificador principal es obligatorio.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo (opcional)',
                      helperText: 'Permite correlacionar menciones en directorios y registros.',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                  UsernameChipsInput(
                    usernames: _associatedUsernames,
                    onChanged: (updated) {
                      setState(() => _associatedUsernames = updated);
                    },
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono de contacto (opcional)',
                      helperText:
                          'Para detectar números filtrados en bases de datos.',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    color: colors.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: CheckboxListTile(
                      value: _consentSelfAudit,
                      onChanged: (val) {
                        setState(() => _consentSelfAudit = val ?? false);
                      },
                      title: Text(
                        'Autorizo la auto-auditoría ética de esta identidad',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Osisn\'t únicamente consultará bases de datos de filtraciones públicas y fuentes abiertas para tu propia protección.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppPalette.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppPalette.error),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: AppPalette.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppPalette.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submitAndStart,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.shield_rounded),
                    label: Text(
                      widget.isInitialOnboarding
                          ? 'Guardar e Iniciar Auditoría'
                          : 'Guardar Cambios',
                    ),
                  ),
                  if (widget.isInitialOnboarding) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isSubmitting ? null : _skip,
                      child: const Text('Configurar más tarde (iniciar en 0)'),
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
}
