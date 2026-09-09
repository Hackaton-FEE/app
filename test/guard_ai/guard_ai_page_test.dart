import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/guard_ai/data/demo_guard_ai_repository.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_controller.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'guard_ai_controller_test.dart' show ControlledRepository;

void main() {
  Future<void> start(
    WidgetTester tester,
    GuardAiController controller, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: GuardAiPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(target));
    await tester.pumpAndSettle();
  }

  Future<void> guidelines(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  testWidgets(
    'suggestions advance a conversation and free text stays editable',
    (tester) async {
      final controller = GuardAiController(DemoGuardAiRepository());
      addTearDown(controller.dispose);
      await start(tester, controller);
      final first = find.text('Revisar mis datos');
      await reveal(tester, first);
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(controller.conversation.messages, hasLength(3));
      final second = find.text('En un buscador');
      await reveal(tester, second);
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(
        controller.conversation.messages.last.text,
        contains('página que'),
      );
      await reveal(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Un borrador propio');
      expect(controller.draft, 'Un borrador propio');
      await tester.pumpAndSettle();
      expect(find.text('Preparar una lista'), findsNothing);
    },
  );

  for (final scenario in [
    (const Size(390, 844), 1.0),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets('chat, keyboard and errors are usable at $scenario', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final controller = GuardAiController(DemoGuardAiRepository());
      addTearDown(controller.dispose);
      try {
        await start(tester, controller, size: scenario.$1, scale: scenario.$2);
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSemantics(find.text('Tu privacidad, paso a paso'))
              .getSemanticsData()
              .flagsCollection
              .isHeader,
          isTrue,
        );
        await guidelines(tester);
        final suggestion = find.text('Revisar mis datos');
        await reveal(tester, suggestion);
        await guidelines(tester);
        final field = find.byType(TextField);
        await reveal(tester, field);
        await tester.enterText(field, ' ');
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        final send = find.byKey(const Key('guard-ai-send'));
        await reveal(tester, send);
        expect(
          tester.getRect(send).bottom,
          lessThanOrEqualTo(scenario.$1.height - 260),
        );
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(controller.error, contains('Escribe un mensaje'));
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
        await guidelines(tester);
        await reveal(tester, field);
        await tester.enterText(field, 'Revisar un perfil');
        await reveal(tester, send);
        await tester.tap(send);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(controller.error, isNull);
        expect(controller.conversation.messages, hasLength(3));
        expect(tester.takeException(), isNull);
        await guidelines(tester);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets(
    'help and reopening the page preserve the draft and conversation',
    (tester) async {
      final controller = GuardAiController(DemoGuardAiRepository());
      addTearDown(controller.dispose);
      await start(tester, controller, size: const Size(320, 640), scale: 2);
      await reveal(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Borrador ficticio');
      await tester.tap(find.byTooltip('Ayuda de GuardAI'));
      await tester.pumpAndSettle();
      expect(find.text('Cómo usar GuardAI'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final back = find.text('Volver al chat');
      await reveal(tester, back);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(controller.draft, 'Borrador ficticio');
      await tester.pumpWidget(const SizedBox());
      await start(tester, controller);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Borrador ficticio',
      );
      expect(controller.conversation.messages, hasLength(1));
    },
  );

  testWidgets(
    'failed reply retains input with visible recovery and no success',
    (tester) async {
      final repository = ControlledRepository();
      final controller = GuardAiController(repository);
      addTearDown(controller.dispose);
      await start(tester, controller);
      await reveal(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Texto ficticio');
      final send = find.byKey(const Key('guard-ai-send'));
      await reveal(tester, send);
      await tester.tap(send);
      await tester.pump();
      expect(find.text('Preparando respuesta…'), findsOneWidget);
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      repository.pending.completeError(Exception('No disponible'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guard-ai-error')), findsOneWidget);
      expect(controller.conversation.messages, hasLength(1));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Texto ficticio',
      );
      expect(find.text('Respuesta de ejemplo lista.'), findsNothing);
      expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
    },
  );
}
