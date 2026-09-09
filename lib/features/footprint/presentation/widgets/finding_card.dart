import 'package:flutter/material.dart';

import '../../domain/footprint_item.dart';

class FindingCard extends StatelessWidget {
  const FindingCard({required this.item, required this.onTap, super.key});

  final FootprintItem item;
  final VoidCallback onTap;

  IconData _categoryIcon(FootprintCategory category) => switch (category) {
    FootprintCategory.socialProfile => Icons.account_circle_outlined,
    FootprintCategory.exposedContact => Icons.alternate_email_rounded,
    FootprintCategory.dataBreach => Icons.lock_outline_rounded,
    FootprintCategory.dataBroker => Icons.manage_search_rounded,
  };

  Color _riskColor(FootprintRisk risk) => switch (risk) {
    FootprintRisk.high => const Color(0xFF9C4635),
    FootprintRisk.medium => const Color(0xFF866117),
    FootprintRisk.low => const Color(0xFF35634A),
  };

  String _riskText(FootprintRisk risk) => switch (risk) {
    FootprintRisk.high => 'Prioridad alta',
    FootprintRisk.medium => 'Prioridad media',
    FootprintRisk.low => 'Prioridad baja',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Semantics(
      button: true,
      hint: 'Abrir el ejemplo y sus pasos sugeridos',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _categoryIcon(item.category),
                      color: colors.primary,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.platform,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _riskText(item.riskLevel),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _riskColor(item.riskLevel),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
