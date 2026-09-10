import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/footprint/presentation/widgets/footprint_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scrolling does not rebuild the action buttons', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var scans = 0;
    var chats = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          extendBody: true,
          bottomNavigationBar: FootprintActionBar(
            onScan: () => scans++,
            onGuardAi: () => chats++,
          ),
          body: ListView.builder(
            controller: controller,
            itemCount: 100,
            itemExtent: 72,
            itemBuilder: (_, index) => Text('Hallazgo de ejemplo $index'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scan = find.byKey(const Key('dashboard-scan-fab'));
    final chat = find.byKey(const Key('dashboard-guardai-fab'));
    final scanWidget = tester.widget(scan);
    final chatWidget = tester.widget(chat);
    final scanRect = tester.getRect(scan);
    for (final offset in [25.0, 75.0, 250.0, 600.0, 0.0]) {
      controller.jumpTo(offset);
      await tester.pumpAndSettle();
      expect(tester.widget(scan), same(scanWidget));
      expect(tester.widget(chat), same(chatWidget));
      expect(tester.getRect(scan), scanRect);
    }
    await tester.tap(scan);
    await tester.tap(chat);
    expect(scans, 1);
    expect(chats, 1);
  });

  testWidgets('scan state updates without disabling GuardAI', (tester) async {
    var scanning = false;
    var chats = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              bottomNavigationBar: FootprintActionBar(
                scanning: scanning,
                onScan: () {},
                onGuardAi: () => chats++,
              ),
            );
          },
        ),
      ),
    );
    update(() => scanning = true);
    await tester.pumpAndSettle();
    expect(find.text('Analizando'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('dashboard-scan-fab')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('dashboard-guardai-fab')));
    expect(chats, 1);
    update(() => scanning = false);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('dashboard-scan-fab')))
          .onPressed,
      isNotNull,
    );
  });
}
