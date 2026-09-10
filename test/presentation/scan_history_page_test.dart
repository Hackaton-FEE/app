import 'package:fee_app/features/footprint/data/mock_footprint_repository.dart';
import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/cases/domain/privacy_case.dart';
import 'package:fee_app/features/footprint/data/local_scan_history_repository.dart';
import 'package:fee_app/features/footprint/domain/footprint_item.dart';
import 'package:fee_app/features/footprint/domain/scan_history_entry.dart';
import 'package:fee_app/features/footprint/presentation/scan_history_controller.dart';
import 'package:fee_app/features/footprint/presentation/scan_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../footprint/fake_scan_history_storage.dart';

void main() {
  group('ScanHistoryPage', () {
    late FakeScanHistoryStorage storage;
    late LocalScanHistoryRepository repository;
    late ScanHistoryController controller;

    setUp(() {
      storage = FakeScanHistoryStorage();
      repository = LocalScanHistoryRepository(storage: storage);
      controller = ScanHistoryController(repository);
    });

    Widget buildTestWidget({
      ValueChanged<dynamic>? onSelectProfile,
      VoidCallback? onStartScan,
    }) {
      return MaterialApp(
        theme: buildAppTheme(),
        home: ScanHistoryPage(
          controller: controller,
          onSelectProfile: onSelectProfile,
          onStartScan: onStartScan,
        ),
      );
    }

    testWidgets('displays 3-day retention notice and empty state initially', (
      tester,
    ) async {
      await controller.load();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Historial de escaneos'), findsOneWidget);
      expect(find.text('Conservación por 3 días'), findsOneWidget);
      expect(
        find.textContaining('registros con más de 72 horas'),
        findsOneWidget,
      );
      expect(find.text('Sin escaneos recientes'), findsOneWidget);
    });

    testWidgets('renders scan card with risk badge and details', (
      tester,
    ) async {
      final entry = ScanHistoryEntry(
        id: 'scan-ui-1',
        targetIdentity: 'persona@empresa.com',
        scannedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
        exposureScore: 65,
        overallRisk: FootprintRisk.high,
        highRiskCount: 1,
        mediumRiskCount: 1,
        lowRiskCount: 0,
        items: [
          FootprintItem(
            id: 'item-1',
            platform: 'Bases Filtradas',
            category: FootprintCategory.dataBreach,
            riskLevel: FootprintRisk.high,
            title: 'Credenciales expuestas',
            description: 'Contraseñas expuestas en filtración',
            exposedData: ['Email', 'Password'],
            sourceUrl: 'https://example.com',
            recommendedAction: 'Cambiar clave',
            suggestedCaseCategory: CaseCategory.personalData,
          ),
        ],
      );

      await repository.saveScan(entry);
      await controller.load();

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('persona@empresa.com'), findsOneWidget);
      expect(find.text('Riesgo alto'), findsOneWidget);
      expect(find.text('Exposición: 65/100'), findsOneWidget);
      expect(find.text('1 hallazgos'), findsOneWidget);
      expect(find.textContaining('Expira en'), findsOneWidget);

      // Tap card to open detail sheet
      await tester.tap(find.byKey(const Key('scan-history-card-scan-ui-1')));
      await tester.pumpAndSettle();

      expect(find.text('Detalle del escaneo'), findsOneWidget);
      expect(find.text('Credenciales expuestas'), findsOneWidget);
      expect(find.text('Bases Filtradas'), findsOneWidget);
    });

    testWidgets('allows deleting a scan from history', (tester) async {
      final entry = ScanHistoryEntry(
        id: 'to-delete',
        targetIdentity: 'borrar@ejemplo.com',
        scannedAt: DateTime.now().toUtc(),
        exposureScore: 20,
        overallRisk: FootprintRisk.low,
        highRiskCount: 0,
        mediumRiskCount: 0,
        lowRiskCount: 1,
        items: [],
      );

      await repository.saveScan(entry);
      await controller.load();

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('borrar@ejemplo.com'), findsOneWidget);

      // Tap delete button
      await tester.tap(find.byTooltip('Eliminar escaneo'));
      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar este escaneo?'), findsOneWidget);
      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();
      expect(find.text('borrar@ejemplo.com'), findsNothing);
      expect(find.text('Sin escaneos recientes'), findsOneWidget);
    });
    testWidgets(
      'history remains accessible at 320 px and 200 percent text with deletion failure',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        try {
          final profile = await MockFootprintRepository().getProfile();
          await controller.recordScan(profile);
          await tester.pumpWidget(buildTestWidget());
          await tester.pumpAndSettle();
          final card = find.byKey(
            Key('scan-history-card-${controller.entries.single.id}'),
          );
          await tester.scrollUntilVisible(card, 180);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.tap(card);
          await tester.pumpAndSettle();
          expect(find.text('Detalle del escaneo'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await tester.tap(find.byTooltip('Cerrar'));
          await tester.pumpAndSettle();
          final remove = find.byTooltip('Eliminar escaneo');
          await tester.ensureVisible(remove);
          await tester.pumpAndSettle();
          await tester.tap(remove);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
          expect(controller.count, 1);
          await tester.tap(remove);
          await tester.pumpAndSettle();
          storage.failDelete = true;
          await tester.tap(find.text('Borrar'));
          await tester.pumpAndSettle();
          expect(controller.error, isNotNull);
          expect(controller.count, 1);
          storage.failDelete = false;
          await tester.ensureVisible(find.text('Reintentar'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Reintentar'));
          await tester.pumpAndSettle();
          expect(controller.error, isNull);
          expect(controller.count, 0);
        } finally {
          semantics.dispose();
        }
      },
    );
  });
}
