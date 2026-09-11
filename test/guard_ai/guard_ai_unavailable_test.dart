import 'dart:io';
import 'dart:ui' as ui;

import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/guard_ai/data/unavailable_guard_ai_repository.dart';
import 'package:fee_app/features/guard_ai/data/unavailable_guard_ai_action_executor.dart';
import 'package:fee_app/features/guard_ai/domain/guard_ai_repository.dart';
import 'package:fee_app/features/guard_ai/domain/guard_ai_action_executor.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_controller.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_process_controller.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'unconnected chats never synthesize replies and retain unsent drafts',
    () async {
      final controller = GuardAiController(UnavailableGuardAiRepository());
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.conversation.messages, isEmpty);
      expect(controller.conversation.suggestions, isEmpty);
      final first = controller.chatId;
      for (final prompt in [
        'Revisar mi perfil',
        'usuario.demo en ejemplo.com',
        'ayudame a arreglar mi problema',
      ]) {
        controller.setDraft(prompt);
        expect(await controller.sendDraft(), isFalse);
        expect(controller.draft, prompt);
        expect(controller.conversation.messages, isEmpty);
        expect(controller.error, contains('no se ha enviado'));
      }
      await controller.newChat();
      expect(controller.conversation.messages, isEmpty);
      expect(controller.conversation.suggestions, isEmpty);
      controller.selectChat(first);
      expect(controller.draft, 'ayudame a arreglar mi problema');
    },
  );

  test('the configured repository supplies replies in each new chat', () async {
    final controller = GuardAiController(
      _SuppliedRepository(),
      createRepository: _SuppliedRepository.new,
    );
    addTearDown(controller.dispose);
    await controller.load();
    for (var i = 0; i < 2; i++) {
      controller.setDraft('consulta $i');
      expect(await controller.sendDraft(), isTrue);
      expect(controller.conversation.messages.last.text, 'Respuesta recibida');
      expect(controller.conversation.messages, hasLength(2));
      await controller.newChat();
    }
  });

  test('unconnected actions cannot report success', () async {
    final controller = GuardAiProcessController(
      action: 'Acción pendiente',
      executor: UnavailableGuardAiActionExecutor(),
    );
    addTearDown(controller.dispose);
    await controller.start();
    expect(controller.status, GuardAiProcessStatus.failed);
    expect(controller.steps, [
      GuardAiStepStatus.failed,
      GuardAiStepStatus.pending,
      GuardAiStepStatus.pending,
    ]);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('empty chat and unavailable notice at ${scale}x', (
      tester,
    ) async {
      tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture =
          Platform.environment['GUARDAI_CAPTURE'] == '1' && scale == 1;
      if (capture) {
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
      final controller = GuardAiController(UnavailableGuardAiRepository());
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(key: preview, child: child!),
          ),
          home: GuardAiPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> screenshot(String name) async {
        if (!capture) return;
        final boundary =
            preview.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('docs/images/$name.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      expect(find.byTooltip('Mostrar sugerencias'), findsNothing);
      expect(find.text('Informe de privacidad'), findsNothing);
      await screenshot('guardai-empty');
      await tester.enterText(find.byType(TextField), 'Consulta de prueba');
      await tester.tap(find.byKey(const Key('guard-ai-send')));
      await tester.pumpAndSettle();
      expect(controller.conversation.messages, isEmpty);
      expect(controller.draft, 'Consulta de prueba');
      expect(
        find.text(
          'GuardAI aún no está conectado. Tu mensaje no se ha enviado.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await screenshot('guardai-unavailable');
    });
  }
}

class _SuppliedRepository implements GuardAiRepository {
  @override
  Future<GuardAiConversation> loadConversation() async => GuardAiConversation();
  @override
  Future<GuardAiConversation> reply(GuardAiInput input) async =>
      GuardAiConversation(
        messages: [
          GuardAiMessage(role: GuardAiRole.person, text: input.text),
          const GuardAiMessage(
            role: GuardAiRole.assistant,
            text: 'Respuesta recibida',
          ),
        ],
      );
}
