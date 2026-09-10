import 'package:flutter/material.dart';

import '../../data/backend_auth_repository.dart';
import '../../domain/scan_capability.dart';

/// Diálogo que consulta el catálogo de proveedores previsto en `GET /api/v1/scans/capabilities`.
class ScanCapabilitiesDialog extends StatefulWidget {
  const ScanCapabilitiesDialog({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<ScanCapabilitiesDialog> createState() => _ScanCapabilitiesDialogState();
}

class _ScanCapabilitiesDialogState extends State<ScanCapabilitiesDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ScanCapabilityProvider> _providers = const [];

  @override
  void initState() {
    super.initState();
    _loadCapabilities();
  }

  Future<void> _loadCapabilities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await widget.authRepository.getScanCapabilities();
      if (!mounted) return;
      setState(() {
        _providers = list;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'El catálogo de motores no está disponible en el servidor.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      title: const Text('Proveedores de escaneo'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(heightFactor: 3, child: CircularProgressIndicator())
            : _errorMessage != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_errorMessage!),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _loadCapabilities,
                    child: const Text('Reintentar'),
                  ),
                ],
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    'Motores y fuentes de auditoría disponibles:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final p in _providers)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        p.available
                            ? Icons.check_circle_rounded
                            : Icons.schedule_rounded,
                        color: p.available
                            ? Colors.green
                            : colors.onSurfaceVariant,
                      ),
                      title: Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Capacidades: ${p.capabilities.join(", ")}',
                      ),
                      trailing: Chip(
                        label: Text(
                          p.available ? 'Disponible' : 'Próximamente',
                        ),
                        backgroundColor: p.available
                            ? colors.primaryContainer
                            : colors.surfaceContainerHighest,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: p.available
                              ? colors.onPrimaryContainer
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Capacidades y fuentes de análisis habilitadas para la auditoría de exposición e identidad digital.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    );
  }
}
