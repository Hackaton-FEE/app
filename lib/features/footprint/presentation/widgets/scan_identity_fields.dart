import 'package:flutter/material.dart';

import '../../domain/scan_identifiers.dart';
import '../../domain/scan_target.dart';

class ScanIdentityFields extends StatefulWidget {
  const ScanIdentityFields({
    this.initialIdentity = '',
    this.email,
    this.phone,
    this.aliases = const [],
    this.enabled = true,
    this.onChanged,
    super.key,
  });

  final String initialIdentity;
  final String? email;
  final String? phone;
  final List<String> aliases;
  final bool enabled;
  final VoidCallback? onChanged;

  @override
  State<ScanIdentityFields> createState() => ScanIdentityFieldsState();
}

class ScanIdentityFieldsState extends State<ScanIdentityFields> {
  final _form = GlobalKey<FormState>();
  final _controllers = List.generate(3, (_) => TextEditingController());
  final _focus = List.generate(3, (_) => FocusNode());
  final _keys = List.generate(3, (_) => GlobalKey());
  late final List<String> _initial;

  @override
  void initState() {
    super.initState();
    String? email = widget.email, phone = widget.phone;
    final aliases = [...widget.aliases];
    try {
      final target = ScanTarget.parse(widget.initialIdentity);
      if (target.type == 'email') email ??= target.identifier;
      if (target.type == 'phone') phone ??= target.identifier;
      if (target.type == 'username' && !aliases.contains(target.identifier)) {
        aliases.insert(0, target.identifier);
      }
    } on FormatException {
      // Legacy empty or name-only profiles require explicit identifiers.
    }
    _initial = [email ?? '', aliases.join(', '), phone ?? ''];
    for (var i = 0; i < 3; i++) {
      _controllers[i].text = _initial[i];
    }
  }

  bool get isDirty => List.generate(
    3,
    (i) => _controllers[i].text != _initial[i],
  ).any((v) => v);
  String get emailDraft => _controllers[0].text.trim();

  String? _error(int index, String value) {
    try {
      switch (index) {
        case 0:
          ScanIdentifiers.validateEmail(value);
        case 1:
          ScanIdentifiers.validateAliases(value);
        case 2:
          ScanIdentifiers.validatePhone(value);
      }
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  ScanIdentifiers? validate() {
    if (!_form.currentState!.validate()) {
      final index = List.generate(
        3,
        (i) => i,
      ).firstWhere((i) => _error(i, _controllers[i].text) != null);
      _focus[index].requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(_keys[index].currentContext!, alignment: .2);
        }
      });
      return null;
    }
    return ScanIdentifiers(
      email: _controllers[0].text,
      aliases: _controllers[1].text,
      phone: _controllers[2].text,
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Los tres campos son obligatorios para intentar los cuatro motores. Solo introduce datos tuyos. Se enviarán a FEE para consultar fuentes externas.',
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 3; i++) ...[
          KeyedSubtree(
            key: _keys[i],
            child: TextFormField(
              key: Key(
                [
                  'scan-identity-field',
                  'scan-aliases-field',
                  'scan-phone-field',
                ][i],
              ),
              controller: _controllers[i],
              focusNode: _focus[i],
              enabled: widget.enabled,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: [
                TextInputType.emailAddress,
                TextInputType.text,
                TextInputType.phone,
              ][i],
              textInputAction: i == 2
                  ? TextInputAction.done
                  : TextInputAction.next,
              maxLines: i == 1 ? null : 1,
              decoration: InputDecoration(
                labelText: [
                  'Correo propio (obligatorio)',
                  'Alias propios (obligatorio)',
                  'Teléfono propio (obligatorio)',
                ][i],
                helperText: [
                  'Holehe: presencia asociada al correo.',
                  'Blackbird y Maigret: separa los alias con comas.',
                  'Ignorant: incluye + y código de país.',
                ][i],
                helperMaxLines: 3,
                errorMaxLines: 5,
              ),
              validator: (value) => _error(i, value ?? ''),
              onChanged: (_) => widget.onChanged?.call(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        const Text(
          'Se intentarán Blackbird, Maigret, Holehe e Ignorant. Las fuentes pueden limitar consultas o fallar; aportar los datos no garantiza resultados.',
        ),
      ],
    ),
  );
}
