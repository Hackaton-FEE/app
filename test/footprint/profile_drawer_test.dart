import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/footprint/presentation/widgets/profile_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('closes the drawer before invoking each destination', (
    tester,
  ) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    final actions = <String>[];

    void recordAction(String action) {
      expect(scaffoldKey.currentState!.isDrawerOpen, isFalse);
      actions.add(action);
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          key: scaffoldKey,
          drawer: ProfileDrawer(
            identity: null,
            onManageAccounts: () => recordAction('logout'),
            onViewHistory: () => recordAction('history'),
            onHelp: () => recordAction('help'),
          ),
          body: const Text('Dashboard'),
        ),
      ),
    );

    for (final key in ['profile-history', 'profile-accounts', 'profile-help']) {
      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
    }
    expect(actions, ['history', 'logout', 'help']);

    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('Cambiar identidad'), findsNothing);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Ayuda')).dy,
      greaterThan(tester.getTopLeft(find.text('Cerrar sesión')).dy),
    );
    await tester.tap(find.text('Mi huella'));
    await tester.pumpAndSettle();
    expect(scaffoldKey.currentState!.isDrawerOpen, isFalse);
    expect(actions, ['history', 'logout', 'help']);
  });

  testWidgets('supports a long identity at 320 px and 200 percent text', (
    tester,
  ) async {
    const identity = 'identidad.ficticia.larga.para.pruebas@example.invalid';
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    final scaffoldKey = GlobalKey<ScaffoldState>();
    var helpOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          key: scaffoldKey,
          drawer: ProfileDrawer(
            identity: identity,
            onHelp: () => helpOpened = true,
          ),
          body: const SizedBox.expand(),
        ),
      ),
    );
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Identidad: $identity'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    final help = find.byKey(const Key('profile-help'));
    await tester.scrollUntilVisible(
      help,
      160,
      scrollable: find.descendant(
        of: find.byType(NavigationDrawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.tap(help);
    await tester.pumpAndSettle();
    expect(helpOpened, isTrue);
    expect(scaffoldKey.currentState!.isDrawerOpen, isFalse);
    semantics.dispose();
  });
}
