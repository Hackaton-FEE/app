import 'package:flutter/material.dart';

class ScanBottomSheet extends StatefulWidget {
  const ScanBottomSheet({
    required this.initialIdentity,
    required this.onScan,
    super.key,
  });

  final String initialIdentity;
  final ValueChanged<String> onScan;

  @override
  State<ScanBottomSheet> createState() => _ScanBottomSheetState();
}

class _ScanBottomSheetState extends State<ScanBottomSheet> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  final _identityFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialIdentity);
  }

  @override
  void dispose() {
    _controller.dispose();
    _identityFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _identityFocus.requestFocus();
      return;
    }
    final value = _controller.text.trim();
    Navigator.of(context).pop();
    widget.onScan(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Explora tu huella',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar análisis',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Ingresa un correo o alias para realizar la auditoría de exposición '
                  'y detectar posibles filtraciones o registros públicos.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const Key('scan-identity-field'),
                  controller: _controller,
                  focusNode: _identityFocus,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.go,
                  decoration: const InputDecoration(
                    labelText: 'Correo o alias (obligatorio)',
                    hintText: 'nombre.usuario@gmail.com',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                    errorMaxLines: 3,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa un correo o alias para continuar.';
                    }
                    if (value.trim().length < 3) {
                      return 'Usa al menos 3 caracteres.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('start-scan-submit-button'),
                  onPressed: _submit,
                  icon: const Icon(Icons.radar_rounded),
                  label: const Text('Iniciar análisis'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
