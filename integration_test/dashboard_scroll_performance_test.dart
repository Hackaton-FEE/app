import 'package:fee_app/app/app.dart';
import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/data/fake_case_storage.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('dashboard scroll frame timings', (tester) async {
    await tester.pumpWidget(
      FeeApp(repository: LocalCaseRepository(storage: FakeCaseStorage())),
    );
    await tester.pumpAndSettle();
    final account = find.byKey(const Key('account-demo-personal'));
    await tester.ensureVisible(account);
    await tester.tap(account);
    await tester.pumpAndSettle();
    final controller = tester
        .widget<CustomScrollView>(find.byKey(const Key('dashboard-scroll')))
        .controller!;

    Future<void> scrollRoundTrip() async {
      await controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 1500),
        curve: Curves.linear,
      );
      await controller.animateTo(
        0,
        duration: const Duration(milliseconds: 1500),
        curve: Curves.linear,
      );
    }

    await scrollRoundTrip().timeout(const Duration(seconds: 10));
    await binding.watchPerformance(() async {
      for (var iteration = 0; iteration < 4; iteration++) {
        await scrollRoundTrip();
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }, reportKey: 'dashboard_scroll');
    binding.reportData!['display_refresh_rate_hz'] =
        tester.view.display.refreshRate;
    expect(controller.offset, 0);
    expect(tester.takeException(), isNull);
  });
}
