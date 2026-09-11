import 'package:flutter/material.dart';

class ScanDraftGuard extends StatefulWidget {
  const ScanDraftGuard({
    required this.dirty,
    required this.busy,
    required this.child,
    super.key,
  });
  final bool dirty;
  final bool busy;
  final Widget child;
  @override
  State<ScanDraftGuard> createState() => _ScanDraftGuardState();
}

class _ScanDraftGuardState extends State<ScanDraftGuard> {
  bool _allowExit = false;
  bool _asking = false;
  Future<void> _leave() async {
    if (widget.busy || _asking) return;
    _asking = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar los cambios?'),
        content: const Text('Los datos que editaste no se conservarán.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    _asking = false;
    if (!mounted || discard != true) return;
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.busy && (_allowExit || !widget.dirty),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: widget.child,
  );
}
