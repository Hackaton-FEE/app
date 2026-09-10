import 'package:flutter/material.dart';

import '../domain/footprint_profile.dart';
import '../domain/scan_history_entry.dart';
import 'scan_history_controller.dart';
import 'widgets/scan_history_card.dart';
import 'widgets/scan_history_detail.dart';

class ScanHistoryPage extends StatelessWidget {
  const ScanHistoryPage({
    required this.controller,
    this.onSelectProfile,
    this.onStartScan,
    super.key,
  });
  final ScanHistoryController controller;
  final ValueChanged<FootprintProfile>? onSelectProfile;
  final VoidCallback? onStartScan;

  Future<void> _confirmDelete(
    BuildContext context, [
    ScanHistoryEntry? entry,
  ]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          entry == null
              ? '¿Borrar todo el historial?'
              : '¿Eliminar este escaneo?',
        ),
        content: Text(
          entry == null
              ? 'Se eliminarán los escaneos guardados para esta cuenta en este dispositivo. Los casos se conservan.'
              : 'Se eliminará el escaneo de ${entry.targetIdentity} del historial de este dispositivo. Los casos se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (entry == null) {
        await controller.clearAll();
      } else {
        await controller.deleteScan(entry.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Historial de escaneos'),
        actions: [
          if (controller.entries.isNotEmpty)
            IconButton(
              tooltip: 'Borrar historial',
              onPressed: controller.isLoading
                  ? null
                  : () => _confirmDelete(context),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CustomScrollView(
              key: const Key('scan-history-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Conservación por 3 días',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Historial de escaneos guardados localmente en este dispositivo. Los registros con más de 72 horas se depuran automáticamente al actualizar.',
                        ),
                        if (controller.isLoading) ...[
                          const SizedBox(height: 16),
                          const LinearProgressIndicator(
                            semanticsLabel: 'Actualizando historial',
                          ),
                        ],
                        if (controller.error != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(controller.error!),
                          ),
                          OutlinedButton(
                            onPressed: controller.isLoading
                                ? null
                                : controller.retry,
                            child: const Text('Reintentar'),
                          ),
                        ],
                        if (!controller.isLoading &&
                            controller.error == null &&
                            controller.entries.isEmpty) ...[
                          const SizedBox(height: 32),
                          const Icon(Icons.history_rounded, size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'Sin escaneos recientes',
                            textAlign: TextAlign.center,
                          ),
                          if (onStartScan != null) ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              key: const Key('history-start-scan-button'),
                              onPressed: () {
                                Navigator.pop(context);
                                onStartScan!();
                              },
                              icon: const Icon(Icons.search),
                              label: const Text('Realizar un escaneo'),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  sliver: SliverList.builder(
                    itemCount: controller.entries.length,
                    itemBuilder: (context, index) {
                      final entry = controller.entries[index];
                      return IgnorePointer(
                        ignoring: controller.isLoading,
                        child: ScanHistoryCard(
                          key: Key('scan-history-card-${entry.id}'),
                          entry: entry,
                          onOpen: () => showScanHistoryDetail(
                            context,
                            entry,
                            onSelectProfile: onSelectProfile,
                          ),
                          onDelete: () => _confirmDelete(context, entry),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
