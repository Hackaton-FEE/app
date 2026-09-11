import 'support/ready_identity_repository.dart';
import 'support/demo_guard_ai_repository.dart';
import 'support/demo_account_repository.dart';

import 'package:fee_app/app/app.dart';
import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:fee_app/features/cases/presentation/case_form_page.dart';
import 'package:fee_app/features/footprint/data/local_scan_history_repository.dart';
import 'package:fee_app/features/footprint/presentation/scan_history_page.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_page.dart';

import 'support/mock_footprint_repository.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fee_app/features/footprint/presentation/widgets/dashboard_spotlight.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data/fake_case_storage.dart';
import 'footprint/fake_scan_history_storage.dart';

void main() {
  late FakeCaseStorage storage;
  late FakeScanHistoryStorage scanStorage;
  late MockFootprintRepository footprintRepo;

  setUp(() {
    storage = FakeCaseStorage();
    scanStorage = FakeScanHistoryStorage();
    footprintRepo = MockFootprintRepository();
  });

  Future<void> startDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      FeeApp(
        guardAiRepositoryFactory: (_) => DemoGuardAiRepository(),
        identityProfileRepository: ReadyIdentityRepository(),
        accountRepository: DemoAccountRepository(),
        repository: LocalCaseRepository(storage: storage),
        footprintRepositoryFactory: (_) => footprintRepo,
        scanHistoryRepositoryFactory: (_) =>
            LocalScanHistoryRepository(storage: scanStorage),
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
    expect(await scanStorage.readAll(), hasLength(1));
  });

  testWidgets(
    'spotlight darkens the background but preserves the active target',
    (tester) async {
      await startDashboard(tester);
      Future<List<int>> pixelsAt(List<Offset> points) async {
        final widget = tester.widget<DashboardSpotlight>(
          find.byType(DashboardSpotlight),
        );
        final boundary =
            widget.surfaceKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        return (await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final pixels = points
              .map(
                (point) => bytes.getUint32(
                  (point.dy.floor() * image.width + point.dx.floor()) * 4,
                ),
              )
              .toList();
          image.dispose();
          return pixels;
        }))!;
      }

      Offset targetPoint() {
        final widget = tester.widget<DashboardSpotlight>(
          find.byType(DashboardSpotlight),
        );
        final rect = tester.getRect(find.byKey(widget.targetKey));
        return Offset(rect.center.dx, rect.top + 16);
      }

      final before = await pixelsAt([const Offset(5, 100), targetPoint()]);
      await tester.tap(find.byKey(const Key('dashboard-profile-button')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-help')),
        160,
        scrollable: find.descendant(
          of: find.byType(NavigationDrawer),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-help')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-spotlight')), findsOneWidget);
      final after = await pixelsAt([const Offset(5, 100), targetPoint()]);
      expect(after.first >> 24, lessThan((before.first >> 24) ~/ 2));
      expect(after.last, before.last);
      await tester.tap(
        find.byKey(const Key('dashboard-scan-fab')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scan-identity-field')), findsNothing);
      await tester.ensureVisible(find.text('Salir del recorrido'));
      await tester.tap(find.text('Salir del recorrido'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-spotlight')), findsNothing);
      await tester.tap(find.byKey(const Key('dashboard-scan-fab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scan-identity-field')), findsOneWidget);
    },
  );

  testWidgets('help offers a tour with navigation and live feature actions', (
    tester,
  ) async {
    await startDashboard(tester);
    await tester.tap(find.byKey(const Key('dashboard-profile-button')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-help')),
      160,
      scrollable: find.descendant(
        of: find.byType(NavigationDrawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-help')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.textContaining('Paso 1 de 5'), findsOneWidget);
    await tester.ensureVisible(find.text('Siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Anterior'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anterior'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paso 1 de 5'), findsOneWidget);
    for (var step = 0; step < 3; step++) {
      await tester.ensureVisible(find.text('Siguiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('dashboard-guardai-fab')));
    await tester.pumpAndSettle();
    expect(find.byType(GuardAiPage), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Regresar al inicio'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paso 4 de 5'), findsOneWidget);
    await tester.ensureVisible(find.text('Siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Finalizar'));
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

    // Drawer home action returns to Dashboard.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Regresar al inicio'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-scan-fab')), findsOneWidget);
  });

  testWidgets(
    'Scan history button navigates to ScanHistoryPage and can return',
    (tester) async {
      await startDashboard(tester);

      await scrollAndTap(
        tester,
        find.byKey(const Key('recommendation-view-history-button')),
      );

      expect(find.byType(ScanHistoryPage), findsOneWidget);

      // Back to dashboard
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text("Osisn't"), findsOneWidget);
    },
  );

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

  testWidgets('Sidebar profile-history navigates to ScanHistoryPage', (
    tester,
  ) async {
    await startDashboard(tester);

    await tester.tap(find.byKey(const Key('dashboard-profile-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-history')), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-history')));
    await tester.pumpAndSettle();

    expect(find.byType(ScanHistoryPage), findsOneWidget);
    expect(find.text('Historial de escaneos'), findsOneWidget);
  });
  testWidgets(
    'sidebar keeps history and one help entry without removed options',
    (tester) async {
      await startDashboard(tester);
      expect(find.byTooltip('Ayuda de uso'), findsNothing);
      await tester.tap(find.byKey(const Key('dashboard-profile-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-history')), findsOneWidget);
      expect(find.byKey(const Key('profile-help')), findsOneWidget);
      for (final key in [
        'profile-cases',
        'profile-sessions',
        'profile-capabilities',
      ]) {
        expect(find.byKey(Key(key)), findsNothing);
      }
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-help')),
        160,
        scrollable: find.descendant(
          of: find.byType(NavigationDrawer),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-help')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Paso 1 de 5'), findsOneWidget);
    },
  );
}
