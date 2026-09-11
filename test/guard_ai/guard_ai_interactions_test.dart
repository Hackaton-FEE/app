import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:fee_app/app/theme.dart';

import '../support/guard_ai/demo_guard_ai_action_executor.dart';
import '../support/guard_ai/demo_guard_ai_repository.dart';

import 'package:fee_app/features/guard_ai/presentation/guard_ai_controller.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_page.dart';
import 'package:fee_app/features/guard_ai/presentation/widgets/guard_ai_action_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'history restores drafts, topic progress and deletes the active chat',
    () async {
      final controller = GuardAiController(
        DemoGuardAiRepository(),
        createRepository: DemoGuardAiRepository.new,
      );
      addTearDown(controller.dispose);
      await controller.load();
      controller.setDraft('Revisar mis datos');
      await controller.sendDraft();
      controller.setDraft('Mi borrador');
      final first = controller.chatId;
      await controller.newChat();
      expect(controller.conversation.messages, isEmpty);
      controller.selectChat(first);
      expect(controller.draft, 'Mi borrador');
      controller.setDraft('Quiero retirar mis datos');
      await controller.sendDraft();
      expect(
        controller.conversation.messages.last.recommendedAction,
        isNotNull,
      );
      await controller.deleteChat(first);
      expect(controller.chats.containsKey(first), isFalse);
      expect(controller.draft, isEmpty);
      await controller.deleteChat(controller.chatId);
      expect(controller.chats.length, 1);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'recommendation decisions and reminder validation at ${scale}x',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showDialog<String>(
                      context: context,
                      builder: (_) => GuardAiActionDialog(
                        action: 'Dar de baja en página de ejemplo',
                        executor: DemoGuardAiActionExecutor(),
                      ),
                    );
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );
        Future<void> tap(String label) async {
          final text = find.text(label);
          final target = text.evaluate().isNotEmpty
              ? text
              : find.byTooltip(label);
          await tester.ensureVisible(target);
          await tester.tap(target);
          await tester.pumpAndSettle();
        }

        await tap('Abrir');
        void checkActionRow({int count = 3}) {
          final row = find.byKey(const Key('guard-ai-decision-row'));
          final buttons = find.descendant(
            of: row,
            matching: find.byType(FilledButton),
          );
          expect(buttons, findsNWidgets(count));
          final centers = [
            for (var i = 0; i < count; i++) tester.getCenter(buttons.at(i)),
          ];
          expect(centers[0].dy, centers[1].dy);
          if (count == 3) expect(centers[1].dy, centers[2].dy);
          expect(centers[0].dx, lessThan(centers[1].dx));
          if (count == 3) expect(centers[1].dx, lessThan(centers[2].dx));
        }

        checkActionRow();
        await tap('Posponer');
        checkActionRow(count: 2);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        expect(find.text('Volver'), findsNothing);
        await tester.enterText(find.byType(TextFormField), '0');
        await tap('Aceptar recordatorio');
        expect(find.text('Escribe un número entre 1 y 365.'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField), '7');
        await tap('Aceptar recordatorio');
        expect(result, contains('7 días'));
        await tap('Abrir');
        await tap('Aceptar');
        expect(find.text('Proceso'), findsOneWidget);
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.pumpAndSettle();
        await tap('Volver al chat');
        expect(result, contains('correctamente realizada'));
        await tap('Abrir');
        await tap('Rechazar');
        expect(result, contains('rechazada'));
        await tap('Abrir');
        await tap('Posponer');
        await tester.tap(find.byTooltip('Regresar a la recomendación'));
        await tester.pumpAndSettle();
        expect(find.text('Aceptar'), findsOneWidget);
        await tester.tap(find.byTooltip('Cerrar recomendación'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('drawer creates chats and suggestions toggle; mobile preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GuardAiController(
      DemoGuardAiRepository(),
      createRepository: DemoGuardAiRepository.new,
    );
    addTearDown(controller.dispose);
    if (Platform.environment['GUARDAI_CAPTURE'] == '1') {
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
                .then((bytes) => ByteData.sublistView(bytes)),
          );
          await loader.load();
        }
      });
    }
    final preview = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) =>
            RepaintBoundary(key: preview, child: child!),
        home: GuardAiPage(
          controller: controller,
          createActionExecutor: DemoGuardAiActionExecutor.new,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Revisar mis datos'), findsNothing);
    await tester.tap(find.byTooltip('Mostrar sugerencias'));
    await tester.pumpAndSettle();
    expect(find.text('Revisar mis datos'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva conversación').first);
    await tester.pumpAndSettle();
    expect(controller.chats.length, 2);
    expect(controller.conversation.messages, isEmpty);
    expect(find.byKey(const Key('guard-ai-intro')), findsOneWidget);
    expect(find.text('Revisar mis datos'), findsNothing);
    final field = find.byType(TextField);
    await tester.enterText(field, 'Revisar mis datos');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guard-ai-intro')), findsOneWidget);
    await tester.tap(find.byTooltip('Mostrar sugerencias'));
    await tester.pumpAndSettle();
    expect(controller.draft, 'Revisar mis datos');
    expect(find.text('Revisar mi perfil'), findsOneWidget);
    final send = find.byKey(const Key('guard-ai-send'));
    final help = find.byTooltip('Acciones rápidas');
    expect(tester.getCenter(help).dx, greaterThan(tester.getCenter(field).dx));
    expect(tester.getCenter(send).dx, greaterThan(tester.getCenter(help).dx));
    expect(tester.getCenter(send).dy, tester.getCenter(help).dy);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guard-ai-intro')), findsNothing);
    expect(controller.conversation.messages.length, 2);
    expect(find.byTooltip('Mostrar sugerencias'), findsOneWidget);
    await controller.newChat();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guard-ai-intro')), findsOneWidget);
    expect(find.text('Revisar mis datos'), findsNothing);

    expect(tester.takeException(), isNull);
    if (Platform.environment['GUARDAI_CAPTURE'] == '1') {
      Future<void> capture(String name) async {
        final boundary =
            preview.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('docs/images/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('guardai-modular-chat');
      controller.setDraft('Revisar mis datos');
      await controller.sendDraft();
      controller.setDraft('Quiero retirar mis datos');
      await controller.sendDraft();
      await tester.pumpAndSettle();
      final action = find.text(
        controller.conversation.messages.last.recommendedAction!,
      );
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      await capture('guardai-simple-confirmation');
      await tester.tap(find.text('Posponer'));
      await tester.pumpAndSettle();
      await capture('guardai-simple-reminder');
      await tester.tap(find.byTooltip('Regresar a la recomendación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      await capture('guardai-action-process');
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await capture('guardai-action-process-completed');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      await capture('guardai-action-success');
      await tester.tap(find.text('Volver al chat'));
      await tester.pumpAndSettle();
      unawaited(
        showDialog<String>(
          context: tester.element(find.byType(GuardAiPage)),
          builder: (_) => GuardAiActionDialog(
            action: 'Revisar la privacidad de mi perfil',
            executor: DemoGuardAiActionExecutor(failAtStep: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await capture('guardai-action-process-failed');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      await capture('guardai-action-error');
      await tester.tap(find.text('Volver al chat'));
      await tester.pumpAndSettle();
      await controller.newChat();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mostrar sugerencias'));
      await tester.pumpAndSettle();
      await capture('guardai-profile-options');
      await tester.tap(find.text('Revisar mi perfil'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '@usuario.demo');
      await tester.tap(find.byKey(const Key('guard-ai-send')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await capture('guardai-profile-thinking');
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();
      await capture('guardai-profile-report');
      controller.setDraft('Quiero retirar mis datos');
      await controller.sendDraft();
      await tester.pumpAndSettle();
      final recommended = find.text(
        controller.conversation.messages.last.recommendedAction!,
      );
      await tester.dragFrom(const Offset(180, 600), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.ensureVisible(recommended);
      await tester.pumpAndSettle();
      await capture('guardai-profile-recommendation');
      await controller.newChat();
      await tester.pumpAndSettle();
      controller.setDraft('Revisar mi perfil');
      await controller.sendDraft();
      await tester.pumpAndSettle();
      await capture('guardai-demo-username');
      await tester.enterText(
        find.byType(TextField),
        '@usuario.demo en Instagram',
      );
      await tester.tap(find.byKey(const Key('guard-ai-send')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await capture('guardai-demo-thinking');
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();
      await capture('guardai-demo-user-report');
      await tester.enterText(
        find.byType(TextField),
        'ayudame a arreglar mi problema',
      );
      await tester.tap(find.byKey(const Key('guard-ai-send')));
      await tester.pumpAndSettle();
      await capture('guardai-demo-problem-help');
    }
  });
}
