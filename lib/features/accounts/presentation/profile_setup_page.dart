import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/app_logo.dart';
import '../../footprint/presentation/footprint_controller.dart';
import '../../footprint/presentation/widgets/scan_draft_guard.dart';
import '../../footprint/presentation/widgets/scan_identity_fields.dart';
import '../domain/identity_profile.dart';
import '../domain/local_account.dart';
import 'identity_profile_controller.dart';

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
  final _fields = GlobalKey<ScanIdentityFieldsState>();
  bool _consent = true;
  bool _busy = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _consent = widget.identityController.profile?.consentSelfAudit ?? true;
  }

  Future<void> _submit() async {
    final input = _fields.currentState!.validate();
    if (input == null) return;
    if (!_consent) {
      setState(
        () => _error = 'Confirma que auditas tus propios datos para iniciar.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final previous = widget.identityController.profile;
    final profile = IdentityProfile(
      accountId: widget.account.id,
      mainIdentifier: input.email,
      associatedEmail: input.email,
      associatedUsernames: input.aliases,
      phone: input.phone,
      fullName: previous?.fullName,
      consentSelfAudit: true,
      createdAt: previous?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final success = await widget.identityController.save(profile);
    if (!mounted) return;
    if (!success) {
      setState(() {
        _busy = false;
        _error = widget.identityController.error;
      });
      return;
    }
    if (widget.footprintController case final controller?) {
      unawaited(
        controller.scanIdentity(
          input.phone,
          associatedEmail: input.email,
          associatedUsernames: input.aliases,
          consentSelfAudit: true,
        ),
      );
    }
    setState(() {
      _busy = false;
      _dirty = false;
    });
    widget.onCompleted?.call();
    if (mounted && !widget.isInitialOnboarding) Navigator.of(context).pop();
  }

  Future<void> _skip() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await widget.identityController.skipOnboarding(
      identifier: _fields.currentState?.emailDraft ?? '',
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = widget.identityController.error;
    });
    if (saved) widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.identityController.profile;
    return ScanDraftGuard(
      dirty: _dirty,
      busy: _busy,
      child: Scaffold(
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo(size: 52)),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        'Configura tu identidad a proteger',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ScanIdentityFields(
                      key: _fields,
                      initialIdentity:
                          profile?.mainIdentifier ?? widget.account.email,
                      email: profile?.associatedEmail,
                      phone: profile?.phone,
                      aliases: profile?.associatedUsernames ?? const [],
                      enabled: !_busy,
                      onChanged: () => setState(
                        () => _dirty = _fields.currentState!.isDirty,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _consent,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              _consent = value ?? false;
                              _dirty = true;
                            }),
                      title: const Text(
                        'Confirmo que los datos son míos y autorizo la autoauditoría',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(_error!),
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 52),
                      ),
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.shield_rounded),
                      label: Text(
                        (widget.isInitialOnboarding ||
                                widget.footprintController != null)
                            ? 'Guardar e Iniciar Auditoría'
                            : 'Guardar Cambios',
                      ),
                    ),
                    if (widget.isInitialOnboarding) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _busy ? null : _skip,
                        child: const Text(
                          'Configurar más tarde (iniciar en 0)',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
