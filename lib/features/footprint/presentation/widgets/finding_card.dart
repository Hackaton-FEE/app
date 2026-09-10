import 'package:flutter/material.dart';

import '../../../../app/palette.dart';
import '../../domain/footprint_item.dart';
import '../footprint_labels.dart';

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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: item.riskLevel.containerColor,
                          border: Border.all(color: item.riskLevel.color),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.riskLevel.priorityLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppPalette.textPrimary,
                          ),
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
