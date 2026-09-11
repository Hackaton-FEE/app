import 'package:flutter/material.dart';

import '../../domain/scan_identifiers.dart';
import 'scan_draft_guard.dart';
import 'scan_identity_fields.dart';

class ScanBottomSheet extends StatefulWidget {
  const ScanBottomSheet({
    required this.initialIdentity,
    required this.onScan,
    this.email,
    this.phone,
    this.aliases = const [],
    super.key,
  });
  final String initialIdentity;
  final String? email;
  final String? phone;
  final List<String> aliases;
  final Future<void> Function(ScanIdentifiers) onScan;
  @override
  State<ScanBottomSheet> createState() => _ScanBottomSheetState();
}

class _ScanBottomSheetState extends State<ScanBottomSheet> {
  final _fields = GlobalKey<ScanIdentityFieldsState>();
  bool _dirty = false;
  bool _busy = false;
  String? _error;
  Future<void> _submit() async {
    final input = _fields.currentState!.validate();
    if (input == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onScan(input);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'No se pudieron guardar los datos. Se conservan aquí; reintenta.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ScanDraftGuard(
    dirty: _dirty,
    busy: _busy,
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Explora tu huella',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar análisis',
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ScanIdentityFields(
                key: _fields,
                enabled: !_busy,
                initialIdentity: widget.initialIdentity,
                email: widget.email,
                phone: widget.phone,
                aliases: widget.aliases,
                onChanged: () =>
                    setState(() => _dirty = _fields.currentState!.isDirty),
              ),
              const SizedBox(height: 16),
              const Text(
                'Al iniciar confirmas que estos datos son tuyos y autorizas la autoauditoría.',
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Semantics(liveRegion: true, child: Text(_error!)),
              FilledButton.icon(
                key: const Key('start-scan-submit-button'),
                onPressed: _busy ? null : _submit,
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
