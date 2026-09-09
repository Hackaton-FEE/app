import 'package:fee_app/app/app.dart';
import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:fee_app/features/cases/domain/case_input.dart';
import 'package:fee_app/features/cases/domain/privacy_case.dart';
import 'package:fee_app/shared/presentation/status_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_case_storage.dart';

Finder get _scrollable => find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    )
    .first;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250, scrollable: _scrollable);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<FakeCaseStorage> _openDetails(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final storage = FakeCaseStorage();
  final repository = LocalCaseRepository(storage: storage);
  await repository.createCase(
    CaseInput(
      title: 'Caso de prueba',
      sourceUrl: 'https://example.com/caso',
      category: CaseCategory.personalData,
      notes: 'Notas ficticias.',
    ),
  );
  await tester.pumpWidget(FeeApp(repository: repository));
  await tester.pumpAndSettle();
  await _tap(tester, find.text('Caso de prueba'));
  return storage;
}

Future<void> _guidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  testWidgets(
    'archive failure remains readable and permits a successful retry',
    (tester) async {
      final storage = await _openDetails(tester);
      storage.failWrite = true;
      await _tap(tester, find.text('Archivar caso'));
      expect(
        tester.widget<StatusNotice>(find.byType(StatusNotice)).isError,
        isTrue,
      );
      await tester.pump(const Duration(seconds: 30));
      expect(find.byType(StatusNotice), findsOneWidget);
      expect(find.text('Borrador'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await _guidelines(tester);

      storage.failWrite = false;
      await _tap(tester, find.text('Archivar caso'));
      expect(find.text('Archivado'), findsOneWidget);
      expect(
        tester.widget<StatusNotice>(find.byType(StatusNotice)).isError,
        isFalse,
      );
      await tester.pump(const Duration(seconds: 30));
      expect(find.textContaining('Caso archivado.'), findsOneWidget);
    },
  );

  testWidgets(
    'delete identifies the case and preserves context after failure',
    (tester) async {
      final storage = await _openDetails(tester);
      storage.failDelete = true;
      await _tap(tester, find.text('Eliminar caso'));
      expect(find.textContaining('«Caso de prueba»'), findsOneWidget);
      await _guidelines(tester);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      expect(storage.records, hasLength(1));
      expect(
        tester.widget<StatusNotice>(find.byType(StatusNotice)).isError,
        isTrue,
      );
      await tester.tap(find.byTooltip('Ayuda de uso'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Atrás'));
      await tester.pumpAndSettle();
      expect(find.byType(StatusNotice), findsOneWidget);
      storage.failDelete = false;
      await _tap(tester, find.text('Eliminar caso'));
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(storage.records, isEmpty);
      expect(find.text('Mis casos'), findsOneWidget);
    },
  );

  testWidgets('detail, controls and confirmation support large text', (
    tester,
  ) async {
    await _openDetails(tester);
    await _guidelines(tester);
    await _tap(tester, find.text('Eliminar caso'));
    await tester.tap(find.text('Conservar'));
    await tester.pumpAndSettle();
    await _guidelines(tester);
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Eliminar caso'));
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Conservar'));
    expect(find.text('Detalle del caso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
