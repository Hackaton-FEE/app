import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:fee_app/features/cases/domain/case_input.dart';
import 'package:fee_app/features/cases/domain/privacy_case.dart';
import 'package:fee_app/features/cases/presentation/case_form_page.dart';
import 'package:fee_app/features/cases/presentation/cases_controller.dart';
import 'package:fee_app/features/help/presentation/help_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_case_storage.dart';

// These checks exercise Flutter focus, semantics and visible render geometry.
// They do not replace TalkBack/VoiceOver testing on physical devices.
void main() {
  late FakeCaseStorage storage;
  late LocalCaseRepository repository;
  late CasesController controller;

  void initialize() {
    storage = FakeCaseStorage();
    repository = LocalCaseRepository(storage: storage);
    controller = CasesController(repository);
  }

  tearDown(() => controller.dispose());

  Finder field(String name) => find.byKey(Key('case-$name'));

  Future<PrivacyCase> seedCase() => repository.createCase(
    CaseInput(
      title: 'Referencia original',
      sourceUrl: 'https://example.com/original',
      category: CaseCategory.personalData,
      notes: 'Notas originales',
    ),
  );

  Future<void> start(
    WidgetTester tester, {
    PrivacyCase? initialCase,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            key: const Key('form-test-home'),
            body: Center(
              child: FilledButton(
                key: const Key('open-form'),
                onPressed: () => Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => CaseFormPage(
                      controller: controller,
                      initialCase: initialCase,
                    ),
                  ),
                ),
                child: const Text('Abrir formulario'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-form')));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String name, String value) async {
    await reveal(tester, field(name));
    await tester.enterText(field(name), value);
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    final save = find.byKey(const Key('save-case'));
    await reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  Future<void> goBack(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  Future<void> fillValid(WidgetTester tester) async {
    await enter(tester, 'title', 'Referencia editada');
    await enter(tester, 'url', 'https://example.com/referencia');
    await reveal(tester, field('category'));
    await tester.tap(field('category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Datos personales').last);
    await tester.pumpAndSettle();
    await enter(tester, 'notes', 'Texto que debe conservarse');
  }

  String textValue(WidgetTester tester, String name) => tester
      .widget<EditableText>(
        find.descendant(of: field(name), matching: find.byType(EditableText)),
      )
      .controller
      .text;

  void expectFocusedError(WidgetTester tester, String name) {
    final hasFocus = name == 'category'
        ? tester
              .widget<DropdownButton<CaseCategory>>(
                find.descendant(
                  of: field(name),
                  matching: find.byType(DropdownButton<CaseCategory>),
                ),
              )
              .focusNode!
              .hasFocus
        : tester
              .widget<EditableText>(
                find.descendant(
                  of: field(name),
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus;
    expect(
      hasFocus,
      isTrue,
      reason: 'The first invalid field needs keyboard focus.',
    );
    final decoration = tester.widget<InputDecorator>(
      find
          .descendant(of: field(name), matching: find.byType(InputDecorator))
          .first,
    );
    final errorText = decoration.decoration.errorText;
    expect(errorText, isNotNull);
    final error = find.text(errorText!);
    expect(error.hitTestable(), findsOneWidget);
    final bounds = tester.getRect(error);
    expect(bounds.top, greaterThanOrEqualTo(kToolbarHeight));
    expect(bounds.bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
  }

  Future<void> checkGuidelines(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  testWidgets('first invalid field receives focus and remains visible at 2x', (
    tester,
  ) async {
    initialize();
    await start(tester, size: const Size(320, 640), textScale: 2);
    await submit(tester);
    expectFocusedError(tester, 'title');
    await enter(tester, 'title', 'Referencia');
    await submit(tester);
    expectFocusedError(tester, 'url');
    await enter(tester, 'url', 'https://example.com/referencia');
    await submit(tester);
    expectFocusedError(tester, 'category');
    expect(storage.records, isEmpty);
  });

  for (final editing in [false, true]) {
    testWidgets('${editing ? 'edit' : 'new'} pristine form returns directly', (
      tester,
    ) async {
      initialize();
      final initial = editing ? await seedCase() : null;
      final original = Map.of(storage.records);
      await start(tester, initialCase: initial);
      await goBack(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CaseFormPage), findsNothing);
      expect(find.byKey(const Key('form-test-home')), findsOneWidget);
      expect(storage.records, original);
    });

    testWidgets(
      '${editing ? 'edit' : 'new'} dirty form can continue or discard',
      (tester) async {
        initialize();
        final initial = editing ? await seedCase() : null;
        final original = Map.of(storage.records);
        await start(tester, initialCase: initial);
        await enter(tester, 'title', 'Cambio sin guardar');
        await enter(tester, 'notes', 'No debe perderse al cancelar');
        await goBack(tester);
        expect(find.text('¿Descartar los cambios?'), findsOneWidget);
        await tester.tap(find.text('Seguir editando'));
        await tester.pumpAndSettle();
        expect(textValue(tester, 'title'), 'Cambio sin guardar');
        expect(textValue(tester, 'notes'), 'No debe perderse al cancelar');
        expect(storage.records, original);
        await goBack(tester);
        await tester.tap(find.text('Descartar cambios'));
        await tester.pumpAndSettle();
        expect(find.byType(CaseFormPage), findsNothing);
        expect(storage.records, original);
      },
    );

    testWidgets(
      '${editing ? 'edit' : 'new'} successful save returns without discard',
      (tester) async {
        initialize();
        final initial = editing ? await seedCase() : null;
        await start(tester, initialCase: initial);
        if (editing) {
          await enter(tester, 'title', 'Referencia editada');
        } else {
          await fillValid(tester);
        }
        await submit(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(CaseFormPage), findsNothing);
        final saved = (await repository.loadCases()).single;
        expect(saved.title, 'Referencia editada');
        if (editing) expect(saved.id, initial!.id);
      },
    );
  }

  testWidgets('failed persistence and a help visit preserve form work', (
    tester,
  ) async {
    initialize();
    await start(tester);
    await fillValid(tester);
    storage.failWrite = true;
    await submit(tester);
    expect(find.byType(CaseFormPage), findsOneWidget);
    expect(storage.records, isEmpty);
    await tester.tap(find.byTooltip('Ayuda de uso'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpPage), findsOneWidget);
    await goBack(tester);
    expect(textValue(tester, 'title'), 'Referencia editada');
    expect(textValue(tester, 'url'), 'https://example.com/referencia');
    expect(textValue(tester, 'notes'), 'Texto que debe conservarse');
    storage.failWrite = false;
    await submit(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CaseFormPage), findsNothing);
    expect(
      (await repository.loadCases()).single.notes,
      'Texto que debe conservarse',
    );
  });

  testWidgets(
    'pending save blocks navigation and restores help after failure',
    (tester) async {
      initialize();
      await start(tester);
      await fillValid(tester);
      final save = find.byKey(const Key('save-case'));
      final help = find.widgetWithIcon(IconButton, Icons.help_outline);

      for (final fails in [true, false]) {
        await reveal(tester, save);
        final gate = Completer<void>();
        storage.writeGate = gate;
        storage.writeStarted = Completer<void>();
        storage.failWrite = fails;
        try {
          await tester.tap(save);
          // A pending spinner intentionally keeps scheduling frames.
          await tester.pump();
          expect(storage.writeStarted!.isCompleted, isTrue);
          expect(controller.state.isSaving, isTrue);
          expect(tester.widget<IconButton>(help).onPressed, isNull);
          await tester.tap(help);
          await tester.tap(find.byType(BackButton));
          await tester.binding.handlePopRoute();
          await tester.pump(const Duration(milliseconds: 50));
          expect(find.byType(CaseFormPage), findsOneWidget);
          expect(find.byType(HelpPage), findsNothing);
          expect(find.byType(AlertDialog), findsNothing);
          expect(storage.records, isEmpty);

          gate.complete();
          await tester.pumpAndSettle();
          if (fails) {
            expect(find.byType(CaseFormPage), findsOneWidget);
            expect(tester.widget<IconButton>(help).onPressed, isNotNull);
            await tester.tap(help);
            await tester.pumpAndSettle();
            expect(find.byType(HelpPage), findsOneWidget);
            await goBack(tester);
            expect(textValue(tester, 'notes'), 'Texto que debe conservarse');
          } else {
            expect(find.byType(CaseFormPage), findsNothing);
            expect(find.byType(HelpPage), findsNothing);
            expect(find.byType(AlertDialog), findsNothing);
            expect(find.byKey(const Key('form-test-home')), findsOneWidget);
            expect(storage.records, hasLength(1));
          }
        } finally {
          if (!gate.isCompleted) {
            gate.complete();
            await tester.pumpAndSettle();
          }
        }
      }
    },
  );

  testWidgets(
    'form and help meet visible target, label and contrast guidelines',
    (tester) async {
      initialize();
      await start(tester);
      await checkGuidelines(tester);
      for (final name in ['title', 'url', 'category', 'notes']) {
        await reveal(tester, field(name));
        final data = tester.getSemantics(field(name)).getSemanticsData();
        if (name == 'notes') {
          expect(data.flagsCollection.isRequired, isNot(Tristate.isTrue));
          expect(data.label, contains('opcional'));
        } else {
          expect(data.flagsCollection.isRequired, Tristate.isTrue);
        }
        await checkGuidelines(tester);
      }
      await reveal(tester, find.byKey(const Key('save-case')));
      await checkGuidelines(tester);
      await tester.tap(find.byTooltip('Ayuda de uso'));
      await tester.pumpAndSettle();
      for (final heading in [
        'Organiza un caso a tu ritmo',
        'Archivar, restaurar o eliminar',
        'Dónde se guarda tu información',
        'Si no puedes guardar o cargar',
        'Qué ayuda está disponible',
      ]) {
        await reveal(tester, find.text(heading));
        expect(
          tester
              .getSemantics(find.text(heading))
              .getSemanticsData()
              .flagsCollection
              .isHeader,
          isTrue,
        );
        await checkGuidelines(tester);
      }
    },
  );

  testWidgets('discard dialog supports large text and accessible actions', (
    tester,
  ) async {
    initialize();
    await start(tester, size: const Size(320, 640), textScale: 2);
    await enter(tester, 'title', 'Referencia sin guardar');
    await goBack(tester);
    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final action in ['Seguir editando', 'Descartar cambios']) {
      await reveal(tester, find.text(action));
      expect(find.text(action).hitTestable(), findsOneWidget);
      await checkGuidelines(tester);
    }
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(textValue(tester, 'title'), 'Referencia sin guardar');
    expect(storage.records, isEmpty);
  });
}
