import 'package:fee_app/app/app.dart';
import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:fee_app/features/cases/presentation/case_form_page.dart';
import 'package:fee_app/features/cases/presentation/cases_page.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_page.dart';
import 'package:fee_app/features/footprint/data/mock_footprint_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data/fake_case_storage.dart';

void main() {
  late FakeCaseStorage storage;
  late MockFootprintRepository footprintRepo;

  setUp(() {
    storage = FakeCaseStorage();
    footprintRepo = MockFootprintRepository();
  });

  Future<void> startDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      FeeApp(
        repository: LocalCaseRepository(storage: storage),
        footprintRepositoryFactory: (_) => footprintRepo,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('account-demo-personal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-demo-personal')));
    await tester.pumpAndSettle();
  }

  Finder findVerticalScrollable() => find
      .byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      )
      .first;

  Future<void> scrollAndTap(
    WidgetTester tester,
    Finder finder, {
    Finder? scrollable,
  }) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: scrollable ?? findVerticalScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Dashboard renders exposure summary, findings and shared bottom actions',
    (tester) async {
      await startDashboard(tester);

      // Verify Title & Identity
      expect(find.text("Osisn't"), findsOneWidget);
      expect(
        find.byKey(const Key('dashboard-target-identity')),
        findsOneWidget,
      );

      // Verify Exposure Gauge
      expect(find.byKey(const Key('dashboard-action-bar')), findsOneWidget);

      // Both actions belong to the shared bottom bar
      expect(find.byKey(const Key('dashboard-scan-fab')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-guardai-fab')), findsOneWidget);

      // Verify Recommendation Card
      expect(
        find.byKey(const Key('recommendation-guardai-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Scan action opens bottom sheet and triggers analysis', (
    tester,
  ) async {
    await startDashboard(tester);

    // Tap Scan action
    await tester.tap(find.byKey(const Key('dashboard-scan-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scan-identity-field')), findsOneWidget);

    // Enter new target and submit
    await tester.enterText(
      find.byKey(const Key('scan-identity-field')),
      'nuevo_objetivo@gmail.com',
    );
    await tester.tap(find.byKey(const Key('start-scan-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('nuevo_objetivo@gmail.com'), findsOneWidget);
  });

  testWidgets('help offers a tour with navigation and live feature actions', (
    tester,
  ) async {
    await startDashboard(tester);
    await tester.tap(find.byTooltip('Ayuda de uso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('¿Quieres un recorrido interactivo?'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 1 de 5'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 1 de 5'), findsOneWidget);
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Abrir GuardAI'));
    await tester.pumpAndSettle();
    expect(find.byType(GuardAiPage), findsOneWidget);
    await tester.tap(find.byType(BackButtonIcon));
    await tester.pumpAndSettle();
    expect(find.text('Paso 4 de 5'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('dashboard-action-bar')), findsOneWidget);
  });

  testWidgets('GuardAI action opens the chat and returns to the dashboard', (
    tester,
  ) async {
    await startDashboard(tester);

    // Open the primary conversation action
    await tester.tap(find.byKey(const Key('dashboard-guardai-fab')));
    await tester.pumpAndSettle();

    expect(find.byType(GuardAiPage), findsOneWidget);
    expect(find.byType(CaseFormPage), findsNothing);

    // Back button pops back to Dashboard
    await tester.tap(find.byType(BackButtonIcon));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-scan-fab')), findsOneWidget);
  });

  testWidgets('View all cases button navigates to CasesPage and can return', (
    tester,
  ) async {
    await startDashboard(tester);

    await scrollAndTap(
      tester,
      find.byKey(const Key('recommendation-view-cases-button')),
    );

    expect(find.byType(CasesPage), findsOneWidget);

    // Back to dashboard
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text("Osisn't"), findsOneWidget);
  });

  testWidgets('Tapping finding card opens detail sheet and pre-fills report', (
    tester,
  ) async {
    await startDashboard(tester);

    // Scroll to and tap first finding card
    await scrollAndTap(
      tester,
      find.byKey(const Key('finding-card-fp-broker-1')),
    );

    expect(find.byKey(const Key('create-report-from-detail')), findsOneWidget);

    final modalScrollable = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .last;

    // Click to create report from detail
    await scrollAndTap(
      tester,
      find.byKey(const Key('create-report-from-detail')),
      scrollable: modalScrollable,
    );

    expect(find.byType(CaseFormPage), findsOneWidget);
    // Verifies pre-filled title from the finding
    expect(
      find.text('Retiro de datos: Radaris / Buscador de Personas'),
      findsOneWidget,
    );
  });
}
