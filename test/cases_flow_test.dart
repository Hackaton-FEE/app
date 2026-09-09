import 'package:fee_app/app/app.dart';
import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:fee_app/features/cases/domain/case_input.dart';
import 'package:fee_app/features/cases/domain/privacy_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data/fake_case_storage.dart';

void main() {
  late FakeCaseStorage storage;

  setUp(() => storage = FakeCaseStorage());

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      FeeApp(repository: LocalCaseRepository(storage: storage)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    if (find.byType(SnackBar).evaluate().isNotEmpty) {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    String title = 'Mi caso de ejemplo',
  }) async {
    await tester.enterText(find.byKey(const Key('case-title')), title);
    await tester.enterText(
      find.byKey(const Key('case-url')),
      'https://example.com/post',
    );
    await tapVisible(tester, find.byKey(const Key('case-category')));
    await tester.tap(find.text('Datos personales').last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'creates, edits, archives, restores and deletes only after confirmation',
    (tester) async {
      await start(tester);
      await tester.tap(find.text('Nuevo caso'));
      await tester.pumpAndSettle();
      await fill(tester);
      await tapVisible(tester, find.byKey(const Key('save-case')));
      expect(find.text('Detalle del caso'), findsOneWidget);
      expect(find.text('Mi caso de ejemplo'), findsOneWidget);
      expect(storage.records, hasLength(1));
      await tapVisible(tester, find.text('Editar caso'));
      await tester.enterText(
        find.byKey(const Key('case-title')),
        'Caso actualizado',
      );
      await tapVisible(tester, find.byKey(const Key('save-case')));
      expect(find.text('Caso actualizado'), findsOneWidget);
      await tapVisible(tester, find.text('Archivar caso'));
      expect(find.text('Restaurar caso'), findsOneWidget);
      await tapVisible(tester, find.text('Restaurar caso'));
      expect(find.text('Archivar caso'), findsOneWidget);
      await tapVisible(tester, find.text('Eliminar caso'));
      await tester.tap(find.text('Conservar'));
      await tester.pumpAndSettle();
      expect(storage.records, hasLength(1));
      await tapVisible(tester, find.text('Eliminar caso'));
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(storage.records, isEmpty);
      expect(find.text('Mis casos'), findsOneWidget);
    },
  );

  testWidgets(
    'validates inputs and keeps form values after a storage failure',
    (tester) async {
      await start(tester);
      await tester.tap(find.text('Nuevo caso'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('save-case')));
      expect(storage.records, isEmpty);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 1500),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Escribe un título para identificar el caso.'),
        findsOneWidget,
      );
      await fill(tester);
      storage.failWrite = true;
      await tapVisible(tester, find.byKey(const Key('save-case')));
      expect(
        find.textContaining('No pudimos acceder al almacenamiento'),
        findsOneWidget,
      );
      expect(find.text('Detalle del caso'), findsNothing);
      expect(storage.records, isEmpty);
      storage.failWrite = false;
      await tapVisible(tester, find.byKey(const Key('save-case')));
      expect(find.text('Mi caso de ejemplo'), findsOneWidget);
      expect(storage.records, hasLength(1));
    },
  );

  testWidgets(
    'loading failure offers retry and does not show an empty case list',
    (tester) async {
      storage.failRead = true;
      await start(tester);
      tester.view.physicalSize = const Size(640, 320);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Nuevo caso'), findsNothing);
      expect(find.text('Volver a intentar'), findsOneWidget);
      storage.failRead = false;
      await tapVisible(tester, find.text('Volver a intentar'));
      expect(find.text('Nuevo caso'), findsOneWidget);
    },
  );

  testWidgets(
    'a new app instance loads saved cases and filters by title or site',
    (tester) async {
      final repository = LocalCaseRepository(storage: storage);
      await repository.createCase(
        CaseInput(
          title: 'Cuenta duplicada',
          sourceUrl: 'https://example.com/profile',
          category: CaseCategory.impersonation,
        ),
      );
      await start(tester);
      await tapVisible(tester, find.byKey(const Key('search-cases')));
      await tester.enterText(
        find.byKey(const Key('search-cases')),
        'sin coincidencias',
      );
      await tester.pumpAndSettle();
      expect(find.text('Cuenta duplicada'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('search-cases')),
        'EXAMPLE.COM',
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Cuenta duplicada'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Cuenta duplicada'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        FeeApp(repository: LocalCaseRepository(storage: storage)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Cuenta duplicada'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Cuenta duplicada'), findsOneWidget);
    },
  );

  testWidgets(
    'home and form remain usable with large text on a narrow screen',
    (tester) async {
      await start(tester);
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('Nuevo caso'));
      await tapVisible(tester, find.byKey(const Key('save-case')));
      expect(storage.records, isEmpty);
      expect(tester.takeException(), isNull);
      expect(find.text('Selecciona un tipo de situación.'), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 3000),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('case-title')));
      expect(find.byKey(const Key('case-title')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('case-title')),
        'Caso accesible',
      );
      await tapVisible(tester, find.byKey(const Key('case-url')));
      await tester.enterText(
        find.byKey(const Key('case-url')),
        'https://example.com/post',
      );
      await tapVisible(tester, find.byKey(const Key('case-category')));
      await tester.tap(find.text('Datos personales').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('save-case')));
      expect(storage.records, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
