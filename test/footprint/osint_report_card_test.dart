import 'dart:io';
import 'dart:ui' as ui;

import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/footprint/domain/osint_report_codec.dart';
import 'package:fee_app/features/footprint/presentation/widgets/exposure_gauge.dart';
import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backend_footprint_repository_test.dart' show dashboardFixture;

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('FEE_CAPTURE_CORRELATION')) return;
    const fonts = String.fromEnvironment('FEE_FLUTTER_FONTS');
    for (final (family, file) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final bytes = await File('$fonts/$file').readAsBytes();
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'correlation is readable and recoverable at text scale $scale',
      (tester) async {
        tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();

        await tester.pumpWidget(
          RepaintBoundary(
            key: const Key('correlation-capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                appBar: AppBar(title: const Text('Tu huella')),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ExposureGauge(
                    profile: FootprintProfile(
                      targetIdentity: 'persona_demo',
                      items: const [],
                      lastScannedAt: DateTime(2026, 9, 10),
                      osintReport: decodeOsintReport(dashboardFixture()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (scale == 1 &&
            const bool.fromEnvironment('FEE_CAPTURE_CORRELATION')) {
          tester.view.physicalSize = const Size(390, 1100);
          await tester.pumpAndSettle();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('correlation-capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File('docs/images/exposure-integrated-result.png')
                .writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
          tester.view.physicalSize = const Size(390, 844);
          await tester.pumpAndSettle();
        }
        expect(find.text('Resultado parcial'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const Key('show-osint-correlation')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('show-osint-correlation')));
        await tester.pumpAndSettle();
        expect(find.text('Mapa de nexos'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('correlation-node-n2')),
          160,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .last,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('correlation-node-n2')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('correlation-node-n2')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('correlation-node-n1')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        if (scale == 1 &&
            const bool.fromEnvironment('FEE_CAPTURE_CORRELATION')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('correlation-capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File('docs/images/osint-nexus-map.png')
                .writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(find.text('Cronología y datos'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cronología y datos'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Patrones de contacto'),
          250,
          scrollable: find.descendant(
            of: find.byKey(const Key('correlation-details-scroll')),
            matching: find.byType(Scrollable),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('show-osint-correlation')), findsOneWidget);
        semantics.dispose();
      },
    );
  }
}
