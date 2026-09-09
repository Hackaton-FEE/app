import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/footprint/domain/footprint_item.dart';
import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:fee_app/features/footprint/presentation/widgets/finding_card.dart';
import 'package:fee_app/features/footprint/presentation/widgets/footprint_explorer.dart';
import 'package:fee_app/features/footprint/presentation/widgets/footprint_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FootprintItem _item(int index, FootprintCategory category) => FootprintItem(
  id: 'example-$index',
  platform: 'Sitio de ejemplo',
  category: category,
  riskLevel: FootprintRisk.low,
  title: 'Hallazgo de ejemplo $index',
  description: 'Descripción del ejemplo',
  exposedData: const ['Alias'],
  sourceUrl: 'https://example.invalid/$index',
  recommendedAction: 'Revisar este ejemplo',
);

void main() {
  Future<void> start(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a long finding list builds on demand and opens its last item', (
    tester,
  ) async {
    final items = List.generate(
      120,
      (index) => _item(index, FootprintCategory.socialProfile),
    );
    FootprintItem? opened;
    await start(
      tester,
      CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: FootprintExplorer(
              profile: FootprintProfile(
                targetIdentity: 'demo@example.invalid',
                items: items,
                lastScannedAt: DateTime(2026, 1, 1),
              ),
              visibleItems: items,
              selectedCategory: null,
              onCategorySelected: (_) {},
              onFindingSelected: (item) => opened = item,
            ),
          ),
        ],
      ),
    );

    final last = find.byKey(const Key('finding-card-example-119'));
    expect(last, findsNothing);
    expect(find.byType(FindingCard).evaluate().length, inExclusiveRange(0, 20));
    await tester.scrollUntilVisible(
      last,
      600,
      maxScrolls: 100,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(last);
    expect(opened?.id, items.last.id);
    expect(find.byType(FindingCard).evaluate().length, lessThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'map selection returns to the matching list and filters can empty it',
    (tester) async {
      final items = [
        _item(0, FootprintCategory.socialProfile),
        _item(1, FootprintCategory.socialProfile),
        _item(2, FootprintCategory.exposedContact),
      ];
      final profile = FootprintProfile(
        targetIdentity: 'demo@example.invalid',
        items: items,
        lastScannedAt: DateTime(2026, 1, 1),
      );
      FootprintCategory? selected;
      late StateSetter rebuild;
      await start(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            final visible = items
                .where((item) => selected == null || item.category == selected)
                .toList();
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: FootprintExplorer(
                    profile: profile,
                    visibleItems: visible,
                    selectedCategory: selected,
                    onCategorySelected: (value) =>
                        setState(() => selected = value),
                    onFindingSelected: (_) {},
                  ),
                ),
              ],
            );
          },
        ),
      );

      expect(find.text('Todos 3'), findsOneWidget);
      expect(find.text('Redes 2'), findsOneWidget);
      expect(find.text('Contacto 1'), findsOneWidget);
      await tester.tap(find.text('Mapa'));
      await tester.pumpAndSettle();
      rebuild(() {});
      await tester.pumpAndSettle();
      expect(find.byType(FootprintMap), findsOneWidget);

      final contact = find.byKey(const Key('footprint-map-exposedContact'));
      await tester.ensureVisible(contact);
      await tester.tap(contact);
      await tester.pumpAndSettle();
      expect(selected, FootprintCategory.exposedContact);
      expect(find.byType(FootprintMap), findsNothing);
      expect(find.text('1 hallazgos de ejemplo'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
            .selected,
        {false},
      );
      expect(find.byKey(const Key('finding-card-example-0')), findsNothing);
      expect(find.byKey(const Key('finding-card-example-2')), findsOneWidget);

      final breaches = find.byKey(const Key('filter-breaches'));
      await tester.ensureVisible(breaches);
      await tester.tap(breaches);
      await tester.pumpAndSettle();
      expect(find.text('0 hallazgos de ejemplo'), findsOneWidget);
      expect(find.text('No hay hallazgos en esta categoría.'), findsOneWidget);
      expect(find.byType(FindingCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
