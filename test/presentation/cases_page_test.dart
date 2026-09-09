import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:fee_app/features/cases/domain/case_input.dart';
import 'package:fee_app/features/cases/domain/privacy_case.dart';
import 'package:fee_app/features/cases/presentation/cases_controller.dart';
import 'package:fee_app/features/cases/presentation/cases_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_case_storage.dart';

void main() {
  testWidgets(
    'reopening cases shows its retained query and allows clearing it',
    (tester) async {
      final repository = LocalCaseRepository(storage: FakeCaseStorage());
      await repository.createCase(
        CaseInput(
          title: 'Referencia de ejemplo',
          sourceUrl: 'https://example.com/referencia',
          category: CaseCategory.personalData,
        ),
      );
      final controller = CasesController(repository);
      addTearDown(controller.dispose);
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CasesPage(controller: controller),
                  ),
                ),
                child: const Text('Abrir casos'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir casos'));
      await tester.pumpAndSettle();
      final search = find.byKey(const Key('search-cases'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'sin coincidencias');
      await tester.pumpAndSettle();
      final list = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      final emptyResult = find.text('No encontramos coincidencias');
      await tester.scrollUntilVisible(emptyResult, 200, scrollable: list.first);
      expect(emptyResult.hitTestable(), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(CasesPage), findsNothing);

      await tester.tap(find.text('Abrir casos'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(search);
      expect(find.text('sin coincidencias'), findsOneWidget);
      await tester.scrollUntilVisible(emptyResult, 200, scrollable: list.first);
      expect(emptyResult.hitTestable(), findsOneWidget);
      await tester.ensureVisible(search);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Limpiar búsqueda'));
      await tester.pumpAndSettle();
      expect(find.text('sin coincidencias'), findsNothing);
      expect(find.text('No encontramos coincidencias'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Referencia de ejemplo'),
        200,
        scrollable: list.first,
      );
      expect(find.text('Referencia de ejemplo').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
