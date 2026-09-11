import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/footprint/domain/footprint_correlation.dart';
import 'package:fee_app/features/footprint/presentation/widgets/correlation_graph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FootprintCorrelation graph({int neighbors = 0, bool empty = false}) =>
    FootprintCorrelation(
      nodes: [
        if (!empty)
          for (var i = 0; i <= neighbors + 1; i++)
            IdentityNode(
              id: 'n$i',
              platform: 'Plataforma $i',
              username: 'persona_demo',
              category: 'social',
            ),
      ],
      edges: [
        for (var i = 1; i <= neighbors; i++)
          IdentityEdge(
            source: i.isEven ? 'n$i' : 'n0',
            target: i.isEven ? 'n0' : 'n$i',
            shared: const ['username', 'masked_email'],
            weight: 2,
          ),
      ],
      clusters: const [],
      contacts: const [],
      timeline: CorrelationTimeline(
        entries: const [],
        oldAccounts: const [],
        oldestPlatform: null,
        oldestDate: null,
        newestPlatform: null,
        newestDate: null,
        spanYears: 0,
      ),
    );

void main() {
  Future<void> reach(
    WidgetTester tester,
    Finder finder, [
    double delta = 150,
  ]) async {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.pumpAndSettle();
  }

  Future<void> showGraph(WidgetTester tester, FootprintCorrelation data) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: CorrelationPage(correlation: data),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty and unconnected accounts do not invent edges', (
    tester,
  ) async {
    await showGraph(tester, graph(empty: true));
    expect(find.textContaining('no incluye cuentas'), findsOneWidget);
    await showGraph(tester, graph());
    await reach(tester, find.textContaining('No se encontraron nexos'));
    expect(find.textContaining('No se encontraron nexos'), findsOneWidget);
    expect(find.byKey(const ValueKey('correlation-node-n1')), findsNothing);
  });

  testWidgets('pages actual neighbors and opens the selected account', (
    tester,
  ) async {
    await showGraph(tester, graph(neighbors: 8));
    final next = find.text('Siguientes');
    await reach(tester, next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.textContaining('Mostrando 7–8 de 8'), findsOneWidget);
    expect(find.byKey(const ValueKey('correlation-node-n9')), findsNothing);
    final node = find.byKey(const ValueKey('correlation-node-n8'));
    await reach(tester, node, -150);
    await tester.tap(node);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 cuenta conectada'), findsOneWidget);
    expect(find.byKey(const ValueKey('correlation-node-n0')), findsOneWidget);
    final connection = find.byKey(const ValueKey('correlation-link-n0'));
    await reach(tester, connection);
    expect(
      find.text('Coinciden en: alias, correo enmascarado'),
      findsOneWidget,
    );
    await tester.tap(connection);
    await tester.pumpAndSettle();
    expect(find.textContaining('Mostrando 1–6 de 8'), findsOneWidget);
  });

  testWidgets('account picker includes isolated accounts', (tester) async {
    await showGraph(tester, graph(neighbors: 1));
    await tester.tap(find.byKey(const Key('correlation-account-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plataforma 2 · persona_demo').last);
    await tester.pumpAndSettle();
    await reach(tester, find.textContaining('No se encontraron nexos'));
    expect(find.textContaining('No se encontraron nexos'), findsOneWidget);
    expect(find.byKey(const ValueKey('correlation-node-n0')), findsNothing);
  });
}
