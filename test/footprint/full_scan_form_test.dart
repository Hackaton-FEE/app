import 'dart:io';
import 'dart:ui' as ui;

import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/footprint/domain/scan_identifiers.dart';
import 'package:fee_app/features/footprint/presentation/widgets/scan_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/scan_form_test_helpers.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    Future<void> Function(ScanIdentifiers) onScan,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) =>
                    ScanBottomSheet(initialIdentity: '', onScan: onScan),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('incomplete form blocks scan and focuses first missing field', (
    tester,
  ) async {
    var calls = 0;
    await open(tester, (_) async {
      calls++;
    });
    final submit = find.byKey(const Key('start-scan-submit-button'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(calls, 0);
    final email = find.byKey(const Key('scan-identity-field'));
    final editable = tester.widget<EditableText>(
      find.descendant(of: email, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);
    expect(find.textContaining('Escribe tu correo'), findsOneWidget);
    await tester.enterText(email, 'owner@example.com');
    await fillScanContacts(tester);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(ScanBottomSheet), findsNothing);
  });

  testWidgets(
    'failed persistence keeps all inputs and canceling discard keeps draft',
    (tester) async {
      await open(tester, (_) async {
        throw StateError('storage');
      });
      await tester.enterText(
        find.byKey(const Key('scan-identity-field')),
        'owner@example.com',
      );
      await fillScanContacts(tester);
      final submit = find.byKey(const Key('start-scan-submit-button'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudieron guardar'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('scan-phone-field')))
            .controller!
            .text,
        '+1 202 555 0123',
      );
      final close = find.byTooltip('Cerrar análisis');
      await tester.ensureVisible(close);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar los cambios?'), findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(find.byType(ScanBottomSheet), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('scan-identity-field')))
            .controller!
            .text,
        'owner@example.com',
      );
    },
  );

  testWidgets('inspect complete scan form with synthetic identifiers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final capture = Platform.environment['FEE_SCAN_CAPTURE'] == '1';
    if (capture) {
      await tester.runAsync(() async {
        final dir = Platform.environment['FEE_FONT_DIR']!;
        for (final entry in {
          'Roboto': 'Roboto-Regular.ttf',
          'MaterialIcons': 'MaterialIcons-Regular.otf',
        }.entries) {
          final loader = FontLoader(entry.key)
            ..addFont(
              File('$dir/${entry.value}')
                  .readAsBytes()
                  .then(ByteData.sublistView),
            );
          await loader.load();
        }
      });
    }
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            body: ScanBottomSheet(
              initialIdentity: 'owner@example.com',
              aliases: const ['owner_demo'],
              phone: '+12025550123',
              onScan: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (capture) {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/images/scan-all-engines.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
