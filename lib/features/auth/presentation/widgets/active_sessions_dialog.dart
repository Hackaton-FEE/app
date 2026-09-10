import 'package:flutter/material.dart';

import '../../data/backend_auth_repository.dart';
import '../../domain/session_info.dart';

/// Diálogo que muestra las sesiones activas (`GET /api/v1/auth/sessions`)
/// y permite revocar sesiones remotas (`DELETE /api/v1/auth/sessions/{id}`).
class ActiveSessionsDialog extends StatefulWidget {
  const ActiveSessionsDialog({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<ActiveSessionsDialog> createState() => _ActiveSessionsDialogState();
}

class _ActiveSessionsDialogState extends State<ActiveSessionsDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  List<SessionInfo> _sessions = const [];
  String? _revokingId;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await widget.authRepository.getSessions();
      if (!mounted) return;
      setState(() {
        _sessions = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'La lista de sesiones no está disponible en el servidor.';
        _isLoading = false;
      });
    }
  }

  Future<void> _revokeSession(String id) async {
    setState(() => _revokingId = id);
    try {
      await widget.authRepository.revokeSession(id);
      if (!mounted) return;
      await _loadSessions();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo revocar la sesión.')),
      );
    } finally {
      if (mounted) setState(() => _revokingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      title: const Text('Sesiones activas'),
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
                    onPressed: _loadSessions,
                    child: const Text('Reintentar'),
                  ),
                ],
              )
            : _sessions.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay sesiones registradas.'),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: _sessions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  final isCurrent = session.isCurrent;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isCurrent
                          ? Icons.phone_android_rounded
                          : Icons.devices_rounded,
                      color: isCurrent
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    title: Text(
                      isCurrent ? 'Esta sesión (actual)' : 'Otra sesión',
                      style: TextStyle(
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      'ID: ${session.id.length > 8 ? session.id.substring(0, 8) : session.id}...\nCreada: ${_formatDate(session.createdAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: isCurrent
                        ? Chip(
                            label: const Text('Actual'),
                            backgroundColor: colors.primaryContainer,
                            labelStyle: TextStyle(
                              color: colors.onPrimaryContainer,
                              fontSize: 12,
                            ),
                          )
                        : _revokingId == session.id
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            tooltip: 'Cerrar esta sesión',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _revokeSession(session.id),
                          ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
