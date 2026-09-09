import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:fee_app/features/cases/domain/case_input.dart';
import 'package:fee_app/features/cases/domain/privacy_case.dart';
import 'package:fee_app/features/cases/presentation/case_form_page.dart';
import 'package:fee_app/features/cases/presentation/cases_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_case_storage.dart';

void main() {
  testWidgets(
    'selected long category is fully visible at 320x640 with 2x text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = LocalCaseRepository(storage: FakeCaseStorage());
      final item = await repository.createCase(
        CaseInput(
          title: 'Referencia de ejemplo',
          sourceUrl: 'https://example.com/referencia',
          category: CaseCategory.impersonation,
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: CaseFormPage(controller: controller, initialCase: item),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('case-category')));
      await tester.pumpAndSettle();

      final selected = find.text('Suplantación de identidad');
      expect(selected.hitTestable(), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(selected);
      // Silent text clipping does not produce a Flutter overflow exception.
      // Measure the complete label at its actual width without a height limit.
      final completeLabel = TextPainter(
        text: paragraph.text,
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
        strutStyle: paragraph.strutStyle,
        locale: paragraph.locale,
        textWidthBasis: paragraph.textWidthBasis,
        textHeightBehavior: paragraph.textHeightBehavior,
      )..layout(maxWidth: paragraph.size.width);
      addTearDown(completeLabel.dispose);
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(completeLabel.height),
        reason: 'The selected category must show every line of its label.',
      );
      final bounds = tester.getRect(selected);
      expect(bounds.top, greaterThanOrEqualTo(kToolbarHeight));
      expect(bounds.bottom, lessThanOrEqualTo(640));
      expect(tester.takeException(), isNull);
    },
  );
}
