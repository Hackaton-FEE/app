import 'package:flutter/material.dart';

import '../../../../app/palette.dart';
import '../../domain/footprint_item.dart';
import '../footprint_labels.dart';

class FootprintDetailSheet extends StatelessWidget {
  const FootprintDetailSheet({
    required this.item,
    required this.onCreateReport,
    super.key,
  });

  final FootprintItem item;
  final ValueChanged<FootprintItem> onCreateReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Detalle del hallazgo',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar detalle',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                item.platform,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Semantics(
                header: true,
                child: Text(
                  item.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: item.riskLevel.containerColor,
                  border: Border.all(color: item.riskLevel.color),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.riskLevel.priorityLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppPalette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(item.description, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              const _SectionTitle(title: 'Datos expuestos'),
              const SizedBox(height: 8),
              ...item.exposedData.map(
                (data) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $data', style: theme.textTheme.bodyMedium),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enlace de referencia',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                item.sourceUrl,
                minLines: 3,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              const _SectionTitle(title: 'Qué puedes hacer'),
              const SizedBox(height: 12),
              _ActionStep(number: '1', text: item.recommendedAction),
              const SizedBox(height: 16),
              const _ActionStep(
                number: '2',
                text:
                    'Prepara un caso con este enlace y tus notas para '
                    'darle seguimiento a tu ritmo.',
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('create-report-from-detail'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onCreateReport(item);
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Preparar caso'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Podrás revisar el título y el enlace antes de guardar. '
                'El caso queda en este dispositivo; no se envía ninguna '
                'solicitud de retiro.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ActionStep extends StatelessWidget {
  const _ActionStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
