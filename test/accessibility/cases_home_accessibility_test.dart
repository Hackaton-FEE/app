import 'dart:ui' show SemanticsAction;

import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:fee_app/features/cases/domain/case_input.dart';
import 'package:fee_app/features/cases/domain/privacy_case.dart';
import 'package:fee_app/features/cases/presentation/cases_controller.dart';
import 'package:fee_app/features/cases/presentation/cases_page.dart';
import 'package:fee_app/features/cases/presentation/widgets/case_card.dart';
import 'package:fee_app/features/help/presentation/help_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_case_storage.dart';

// Flutter's guidelines check visible semantics and geometry. Real screen-reader
// navigation and announcements still need device testing.
void main() {
  late FakeCaseStorage storage;
  late LocalCaseRepository repository;
  late CasesController controller;
  var initialized = false;

  setUp(() {
    storage = FakeCaseStorage();
    initialized = false;
  });

  void initialize() {
    if (initialized) return;
    repository = LocalCaseRepository(storage: storage);
    controller = CasesController(repository);
    initialized = true;
  }

  tearDown(() {
    if (initialized) controller.dispose();
  });

  Future<void> addCases() async {
    initialize();
    await repository.createCase(
      CaseInput(
        title: 'Perfil de ejemplo',
        sourceUrl: 'https://example.com/perfil',
        category: CaseCategory.impersonation,
      ),
    );
    final archived = await repository.createCase(
      CaseInput(
        title: 'Referencia archivada',
        sourceUrl: 'https://example.org/archivo',
        category: CaseCategory.personalData,
      ),
    );
    await repository.setArchived(archived.id, true);
  }

  Future<void> start(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    Widget? home,
    bool loadCases = true,
  }) async {
    initialize();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (loadCases) await controller.load();
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
        home: home ?? CasesPage(controller: controller),
      ),
    );
    if (loadCases) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> checkGuidelines(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  testWidgets('search keeps its accessible label after entering a query', (
    tester,
  ) async {
    await addCases();
    await start(tester);
    final search = find.byKey(const Key('search-cases'));
    await reveal(tester, search);
    await tester.enterText(search, 'perfil');
    await tester.pumpAndSettle();
    final editable = find.descendant(
      of: search,
      matching: find.byType(EditableText),
    );
    final data = tester.getSemantics(editable).getSemanticsData();
    expect(data.flagsCollection.isTextField, isTrue);
    expect(data.label, contains('Buscar casos'));
    expect(data.value, 'perfil');
    expect(find.byTooltip('Limpiar búsqueda'), findsOneWidget);
  });

  testWidgets('case has one labeled button and supports semantic activation', (
    tester,
  ) async {
    await addCases();
    await start(tester);
    final card = find.byType(CaseCard).first;
    await reveal(tester, card);
    final node = tester.getSemantics(card);
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.label, contains('Perfil de ejemplo'));
    expect(data.label, contains('example.com'));
    expect(data.label, contains('Borrador'));
    expect(data.hint, 'Abrir detalle del caso');
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(find.bySemanticsLabel(RegExp('Perfil de ejemplo')), findsOneWidget);
    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
      node.id,
      SemanticsAction.tap,
    );
    await tester.pumpAndSettle();
    expect(find.text('Detalle del caso'), findsOneWidget);
  });

  testWidgets('case can be opened using the keyboard', (tester) async {
    await addCases();
    final item = (await repository.loadCases()).firstWhere(
      (item) => item.status == CaseStatus.draft,
    );
    var opened = 0;
    await start(
      tester,
      home: Scaffold(
        body: Center(
          child: CaseCard(item: item, onTap: () => opened++),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('list heading and result count expose navigation and updates', (
    tester,
  ) async {
    await addCases();
    await start(tester);
    await reveal(tester, find.text('Mis casos'));
    expect(
      tester
          .getSemantics(find.text('Mis casos'))
          .getSemanticsData()
          .flagsCollection
          .isHeader,
      isTrue,
    );
    final search = find.byKey(const Key('search-cases'));
    await reveal(tester, search);
    await tester.enterText(search, 'sin coincidencias');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final count = find.byKey(const Key('case-results-count'));
    await reveal(tester, count);
    final data = tester.getSemantics(count).getSemanticsData();
    expect(data.flagsCollection.isLiveRegion, isTrue);
    expect(data.label, '0 casos activos');
    expect(data.label, isNot(contains('sin coincidencias')));
    expect(data.label, isNot(contains('Perfil de ejemplo')));
    await tester.tap(find.byTooltip('Limpiar búsqueda'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(count).getSemanticsData().label,
      '1 caso activo',
    );
    await tester.tap(find.text('Archivo (1)'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(count).getSemanticsData().label,
      '1 caso archivado',
    );
  });

  testWidgets('storage error is announced and retry remains accessible', (
    tester,
  ) async {
    storage.failRead = true;
    await start(tester);
    final error = find.textContaining('No pudimos acceder al almacenamiento.');
    expect(
      tester
          .getSemantics(error)
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    await checkGuidelines(tester);
    await tester.tap(find.byTooltip('Ayuda de uso'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpPage), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(error, findsOneWidget);
    storage.failRead = false;
    await tester.tap(find.text('Volver a intentar'));
    await tester.pumpAndSettle();
    expect(error, findsNothing);
    expect(find.text('Nuevo caso'), findsOneWidget);
  });

  testWidgets('help remains available before cases finish loading', (
    tester,
  ) async {
    await start(tester, loadCases: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byTooltip('Ayuda de uso'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpPage), findsOneWidget);
    await controller.load();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo caso'), findsOneWidget);
  });

  testWidgets('home meets guidelines with cases, search and empty results', (
    tester,
  ) async {
    await addCases();
    await start(tester);
    await checkGuidelines(tester);
    await reveal(tester, find.byType(CaseCard).first);
    await checkGuidelines(tester);
    final search = find.byKey(const Key('search-cases'));
    await tester.enterText(search, 'no coincide');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await checkGuidelines(tester);
  });

  testWidgets('home remains usable with large text and a narrow viewport', (
    tester,
  ) async {
    await addCases();
    await start(tester, size: const Size(320, 640), textScale: 2);
    expect(tester.takeException(), isNull);
    await reveal(tester, find.text('Archivo (1)'));
    await tester.tap(find.text('Archivo (1)'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(CaseCard).first);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(CaseCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Detalle del caso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
