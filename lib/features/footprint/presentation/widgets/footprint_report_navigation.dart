import 'dart:async';

import '../scan_history_controller.dart';
import '../scan_history_page.dart';
import '../footprint_controller.dart';

import 'package:flutter/material.dart';

import '../../../cases/presentation/case_details_page.dart';
import '../../../cases/presentation/case_form_page.dart';
import '../../../cases/presentation/cases_controller.dart';
import '../../domain/footprint_item.dart';

Future<void> openFootprintReport(
  BuildContext context,
  CasesController casesController,
  FootprintItem sourceItem,
) async {
  final id = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => CaseFormPage(
        controller: casesController,
        initialTitle: 'Retiro de datos: ${sourceItem.platform}',
        initialSourceUrl: sourceItem.sourceUrl,
        initialCategory: sourceItem.suggestedCaseCategory,
        initialNotes:
            'Origen: Hallazgo de Huella Digital\n${sourceItem.description}\n\nDatos expuestos: ${sourceItem.exposedData.join(', ')}',
      ),
    ),
  );
  if (id != null && context.mounted) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            CaseDetailsPage(controller: casesController, caseId: id),
      ),
    );
  }
}

void openScanHistory(
  BuildContext context,
  ScanHistoryController? history,
  FootprintController footprint,
  VoidCallback onStartScan,
) {
  if (history == null) return;
  if (!history.isLoading && history.error == null) unawaited(history.load());
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ScanHistoryPage(
        controller: history,
        onSelectProfile: footprint.isLoading ? null : footprint.setProfile,
        onStartScan: onStartScan,
      ),
    ),
  );
}
