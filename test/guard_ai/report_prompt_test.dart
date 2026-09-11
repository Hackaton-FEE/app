import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:fee_app/features/cases/presentation/case_form_page.dart';
import 'package:fee_app/features/cases/presentation/cases_controller.dart';

import '../support/guard_ai/demo_guard_ai_repository.dart';

import 'package:fee_app/features/guard_ai/presentation/guard_ai_controller.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_case_storage.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'report opens only on request, preserves draft at scale $scale',
      (tester) async {
        tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final storage = FakeCaseStorage();
        final cases = CasesController(LocalCaseRepository(storage: storage));
        final chat = GuardAiController(
          DemoGuardAiRepository(),
          createRepository: DemoGuardAiRepository.new,
        );
        addTearDown(cases.dispose);
        addTearDown(chat.dispose);
        await cases.load();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const [Locale('es')],
            locale: const Locale('es'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: GuardAiPage(controller: chat, casesController: cases),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CaseFormPage), findsNothing);
        expect(find.text('Abrir formulario de reporte'), findsNothing);
        chat.setDraft('Quiero preparar un reporte');
        await chat.sendDraft();
        await tester.pumpAndSettle();
        final open = find.text('Abrir formulario de reporte');
        await tester.scrollUntilVisible(
          open,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(open);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byType(CaseFormPage), findsOneWidget);
        expect(storage.records, isEmpty);
        expect(tester.takeException(), isNull);
        final semantics = tester.ensureSemantics();
        await tester.pumpAndSettle();
        try {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        } finally {
          semantics.dispose();
        }
        final title = find.byKey(const Key('case-title'));
        await tester.ensureVisible(title);
        await tester.enterText(title, 'Perfil de ejemplo');
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('¿Descartar los cambios?'), findsOneWidget);
        await tester.tap(find.text('Seguir editando'));
        await tester.pumpAndSettle();
        expect(find.text('Perfil de ejemplo'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          final url = find.byKey(const Key('case-url'));
          await tester.ensureVisible(url);
          await tester.enterText(url, 'https://example.invalid/perfil');
          final category = find.byKey(const Key('case-category'));
          await tester.ensureVisible(category);
          await tester.tap(category);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Datos personales').last);
          await tester.pumpAndSettle();
          final save = find.text('Guardar caso');
          await tester.ensureVisible(save);
          storage.failWrite = true;
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(storage.records, isEmpty);
          expect(find.byType(CaseFormPage), findsOneWidget);
          expect(cases.state.actionError, isNotNull);
          storage.failWrite = false;
          await tester.ensureVisible(save);
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(storage.records, hasLength(1));
          expect(find.byType(CaseFormPage), findsNothing);
          expect(
            find.text('Caso guardado en este dispositivo. No se ha enviado.'),
            findsOneWidget,
          );
          return;
        }
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Descartar cambios'));
        await tester.pumpAndSettle();
        expect(find.byType(CaseFormPage), findsNothing);
        expect(storage.records, isEmpty);
        expect(chat.conversation.canPrepareReport, isTrue);
      },
    );
  }
}
