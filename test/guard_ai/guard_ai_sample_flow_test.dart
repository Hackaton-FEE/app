import 'dart:io';
import 'dart:ui' as ui;

import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/guard_ai/data/sample_guard_ai_repository.dart';
import 'package:fee_app/features/guard_ai/data/unavailable_guard_ai_repository.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_controller.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sample chat and shortcuts preserve the real draft and never replace failures', () async {
    final controller = GuardAiController(const UnavailableGuardAiRepository());
    addTearDown(controller.dispose);
    await controller.load();
    controller.setDraft('Borrador que quiero conservar');
    expect(
      await controller.sendQuickPrompt(SampleGuardAiRepository.review),
      isFalse,
    );
    expect(controller.draft, 'Borrador que quiero conservar');
    expect(controller.conversation.messages, isEmpty);
    final original = controller.chatId;
    await controller.newChat(repository: SampleGuardAiRepository());
    expect(controller.conversation.isSimulation, isTrue);
    await controller.sendQuickPrompt(SampleGuardAiRepository.review);
    expect(
      controller.conversation.messages.last.text,
      contains('@cliente.demo'),
    );
    controller.selectChat(original);
    expect(controller.conversation.isSimulation, isFalse);
    expect(controller.draft, 'Borrador que quiero conservar');
    expect(controller.conversation.messages, isEmpty);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'sample review, postpone, progress and one home pop at ${scale}x',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();

        final controller = GuardAiController(
          const UnavailableGuardAiRepository(),
        );
        addTearDown(controller.dispose);
        final preview = GlobalKey();
        final navigator = GlobalKey<NavigatorState>();
        final observer = _Pops();
        if (Platform.environment['GUARDAI_SAMPLE_CAPTURE'] == '1') {
          await tester.runAsync(() async {
            final directory = Platform.environment['GUARDAI_FONT_DIR']!;
            for (final entry in {
              'Roboto': 'Roboto-Regular.ttf',
              'MaterialIcons': 'MaterialIcons-Regular.otf',
            }.entries) {
              final loader = FontLoader(entry.key);
              loader.addFont(
                File('$directory/${entry.value}')
                    .readAsBytes()
                    .then(ByteData.sublistView),
              );
              await loader.load();
            }
          });
        }
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            navigatorKey: navigator,
            navigatorObservers: [observer],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: preview, child: child!),
            ),
            home: const Scaffold(body: Text('Inicio único')),
          ),
        );
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => GuardAiPage(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        Future<void> quick(String label) async {
          await tap(find.byKey(const Key('guard-ai-quick-actions')));
          await tap(find.widgetWithText(ListTile, label));
        }

        Future<void> capture(String name) async {
          if (Platform.environment['GUARDAI_SAMPLE_CAPTURE'] != '1' ||
              scale != 1.0) {
            return;
          }
          final boundary =
              preview.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('docs/images/$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await tap(find.byKey(const Key('guard-ai-quick-actions')));
        await capture('guardai-quick-actions');
        await tap(find.text('Conversación de muestra'));
        expect(find.text('Muestra'), findsOneWidget);
        expect(controller.conversation.messages.length, 2);
        await tester.enterText(
          find.byType(TextField),
          'No perder este borrador',
        );
        await quick(SampleGuardAiRepository.review);
        expect(
          controller.conversation.messages.last.text,
          contains('Análisis de muestra'),
        );
        expect(controller.draft, 'No perder este borrador');
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          controller.draft,
        );
        await capture('guardai-sample-review');

        await quick(SampleGuardAiRepository.help);
        expect(find.text('Confirmar acción'), findsOneWidget);
        expect(
          find.textContaining('Simulación: solo verás pasos'),
          findsOneWidget,
        );
        await tap(find.text('Posponer'));
        await tap(find.byTooltip('Aceptar recordatorio'));
        expect(find.text('Confirmar acción'), findsNothing);
        await quick(SampleGuardAiRepository.help);
        await tap(find.text('Aceptar'));
        expect(find.text('Proceso de muestra'), findsOneWidget);
        await capture('guardai-sample-progress');
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.pumpAndSettle();
        expect(find.text('Simulación completada'), findsOneWidget);
        expect(
          find.textContaining('No se modificó ninguna cuenta'),
          findsOneWidget,
        );
        await tap(find.text('Volver al chat'));
        expect(controller.draft, 'No perder este borrador');
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        final popsBeforeHome = observer.pops;
        await tap(find.byIcon(Icons.menu));
        await tap(find.text('Regresar al inicio'));
        expect(find.text('Inicio único'), findsOneWidget);
        expect(find.byType(GuardAiPage), findsNothing);
        expect(observer.pops, popsBeforeHome + 1);
        expect(navigator.currentState!.canPop(), isFalse);
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => GuardAiPage(controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Muestra'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'No perder este borrador',
        );
        semantics.dispose();
      },
    );
  }
}

class _Pops extends NavigatorObserver {
  int pops = 0;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
    super.didPop(route, previousRoute);
  }
}
