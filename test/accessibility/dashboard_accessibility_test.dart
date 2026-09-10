import 'package:fee_app/app/app.dart';
import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:fee_app/features/footprint/data/mock_footprint_repository.dart';
import 'package:fee_app/features/footprint/presentation/widgets/footprint_detail_sheet.dart';
import 'package:fee_app/features/footprint/presentation/widgets/profile_drawer.dart';
import 'package:fee_app/features/footprint/presentation/widgets/scan_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_case_storage.dart';

// These checks cover widget geometry and visible semantics, not a native
// TalkBack/VoiceOver walkthrough or a claim of accessibility conformance.
void main() {
  Future<void> start(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduceMotion);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      FeeApp(
        repository: LocalCaseRepository(storage: FakeCaseStorage()),
        footprintRepositoryFactory: (_) => MockFootprintRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('account-demo-personal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-demo-personal')));
    await tester.pumpAndSettle();
  }

  Finder dashboardScroll() => find.descendant(
    of: find.byKey(const Key('dashboard-scroll')),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  );

  Future<void> reveal(
    WidgetTester tester,
    Finder target, {
    Finder? scrollable,
  }) async {
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: scrollable ?? dashboardScroll(),
      maxScrolls: 80,
    );
    await Scrollable.ensureVisible(tester.element(target));
    await tester.pumpAndSettle();
  }

  Future<void> checkGuidelines(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('inline tour is reachable and dismissible at ${scale}x text', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await start(
          tester,
          size: const Size(320, 640),
          textScale: scale,
          reduceMotion: true,
        );
        await tester.tap(find.byTooltip('Ayuda de uso'));
        await tester.pumpAndSettle();
        for (var step = 1; step <= 5; step++) {
          final heading = find.textContaining('Paso $step de 5');
          expect(heading, findsOneWidget);
          expect(
            tester
                .getSemantics(heading)
                .getSemanticsData()
                .flagsCollection
                .isHeader,
            isTrue,
          );
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byType(PopupMenuButton<String>), findsNothing);
          expect(tester.takeException(), isNull);
          await checkGuidelines(tester);
          final next = find.text(step == 5 ? 'Finalizar' : 'Siguiente');
          await reveal(tester, next);
          await checkGuidelines(tester);
          await tester.tap(next);
          await tester.pumpAndSettle();
        }
        expect(find.textContaining('Paso 5 de 5'), findsNothing);
        final help = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.help_outline),
        );
        expect(help.focusNode!.hasFocus, isTrue);
        await tester.tap(find.byTooltip('Ayuda de uso'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Salir del recorrido'));
        await tester.tap(find.text('Salir del recorrido'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Paso 1 de 5'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('dashboard meets visible guidelines at a normal mobile size', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await start(tester);
      expect(tester.takeException(), isNull);
      final heading = tester
          .getSemantics(find.text('Tu huella digital'))
          .getSemanticsData();
      expect(heading.flagsCollection.isHeader, isTrue);
      await checkGuidelines(tester);

      await reveal(tester, find.byKey(const Key('filter-all')));
      expect(tester.takeException(), isNull);
      await checkGuidelines(tester);
    } finally {
      semantics.dispose();
    }
  });

  for (final sizeAndScale in [
    (const Size(390, 844), 1.0),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets(
      'last finding opens above bottom actions at ${sizeAndScale.$1.width} px '
      'and ${sizeAndScale.$2}x text',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await start(
            tester,
            size: sizeAndScale.$1,
            textScale: sizeAndScale.$2,
          );
          expect(tester.takeException(), isNull);
          await checkGuidelines(tester);
          final lastFinding = find.byKey(const Key('finding-card-fp-github-1'));
          await reveal(tester, lastFinding);
          expect(tester.takeException(), isNull);
          final cardCenter = tester.getCenter(lastFinding);
          final actionBar = tester.getRect(
            find.byKey(const Key('dashboard-action-bar')),
          );
          expect(cardCenter.dy, lessThan(actionBar.top));
          expect(lastFinding.hitTestable(), findsOneWidget);
          await checkGuidelines(tester);

          await tester.tap(lastFinding);
          await tester.pumpAndSettle();
          expect(find.byType(FootprintDetailSheet), findsOneWidget);
          expect(tester.takeException(), isNull);
          await checkGuidelines(tester);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('scan remains accessible with 200 percent text and keyboard', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await start(tester, size: const Size(320, 640), textScale: 2);
      await tester.tap(find.byKey(const Key('dashboard-profile-button')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDrawer), findsOneWidget);
      expect(tester.takeException(), isNull);
      await checkGuidelines(tester);

      expect(find.byKey(const Key('profile-change-identity')), findsNothing);
      await tester.tap(find.byTooltip('Cerrar perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dashboard-scan-fab')));
      await tester.pumpAndSettle();
      expect(find.byType(ScanBottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      final field = find.byKey(const Key('scan-identity-field'));
      await tester.enterText(field, 'identidad.ficticia@example.invalid');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final input = tester
          .getSemantics(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .getSemanticsData();
      expect(input.flagsCollection.isTextField, isTrue);
      expect(input.label, contains('Correo o alias'));
      expect(input.value, 'identidad.ficticia@example.invalid');

      final submit = find.byKey(const Key('start-scan-submit-button'));
      await reveal(
        tester,
        submit,
        scrollable: find
            .descendant(
              of: find.byType(ScanBottomSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getRect(submit).bottom, lessThanOrEqualTo(640 - 260));
      await checkGuidelines(tester);
      await tester.tap(submit);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.byType(ScanBottomSheet), findsNothing);
      await reveal(tester, find.byKey(const Key('dashboard-target-identity')));
      expect(find.text('identidad.ficticia@example.invalid'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('bottom actions avoid lateral system insets in landscape', (
    tester,
  ) async {
    await start(tester, size: const Size(740, 390));
    tester.view.viewPadding = const FakeViewPadding(
      left: 36,
      right: 24,
      bottom: 16,
    );
    addTearDown(tester.view.resetViewPadding);
    await tester.pumpAndSettle();
    final scan = tester.getRect(find.byKey(const Key('dashboard-scan-fab')));
    final create = tester.getRect(
      find.byKey(const Key('dashboard-guardai-fab')),
    );
    expect(scan.left, greaterThanOrEqualTo(36 + 20));
    expect(create.right, lessThanOrEqualTo(740 - 24 - 20));
    expect(create.bottom, lessThanOrEqualTo(390 - 16));
    await tester.tap(find.byKey(const Key('dashboard-scan-fab')));
    await tester.pumpAndSettle();
    expect(find.byType(ScanBottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps actions still and opens scan immediately', (
    tester,
  ) async {
    await start(tester, reduceMotion: true);
    final scan = find.byKey(const Key('dashboard-scan-fab'));
    final initialPosition = tester.getRect(scan);
    await tester.drag(dashboardScroll(), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(scan), initialPosition);

    await tester.tap(scan);
    await tester.pump();
    expect(find.byType(ScanBottomSheet), findsOneWidget);
    final sheetContext = tester.element(find.byType(ScanBottomSheet));
    expect(MediaQuery.disableAnimationsOf(sheetContext), isTrue);
    expect(ModalRoute.of(sheetContext)!.animation!.isCompleted, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  });
}
