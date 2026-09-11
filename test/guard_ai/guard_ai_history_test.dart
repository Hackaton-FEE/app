import 'dart:async';

import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/guard_ai/domain/guard_ai_repository.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_controller.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_page.dart';
import 'package:fee_app/features/guard_ai/presentation/widgets/guard_ai_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a long history mounts only nearby turns and the latest reply', (
    tester,
  ) async {
    final controller = GuardAiController(_LongHistoryRepository());
    addTearDown(controller.dispose);
    await _start(tester, controller);

    expect(controller.conversation.messages, hasLength(161));
    final mounted = find.byWidgetPredicate(_isMessage, skipOffstage: false);
    expect(mounted.evaluate().length, inExclusiveRange(1, 20));
    expect(
      find.byKey(const ValueKey('guard-ai-message-80'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('guard-ai-message-160'), skipOffstage: false),
      findsOneWidget,
    );

    await _reveal(tester, find.byType(TextField, skipOffstage: false));
    expect(mounted.evaluate().length, lessThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'typing updates the draft without rebuilding history or bubbles',
    (tester) async {
      final controller = GuardAiController(_LongHistoryRepository());
      addTearDown(controller.dispose);
      await _start(tester, controller);
      final field = find.byType(TextField, skipOffstage: false);
      await _reveal(tester, field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      var historyBuilds = 0;
      var bubbleBuilds = 0;
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        if (element.widget is GuardAiHistory) historyBuilds++;
        if (_isMessage(element.widget)) bubbleBuilds++;
        previous?.call(element, builtOnce);
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previous);

      for (final draft in ['B', 'Bo', 'Borrador']) {
        await tester.enterText(field, draft);
        await tester.pumpAndSettle();
      }

      expect(controller.draft, 'Borrador');
      expect(historyBuilds, 0);
      expect(bubbleBuilds, 0);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'long history keeps reply recovery visible with keyboard at ${scale}x',
      (tester) async {
        final repository = _LongHistoryRepository();
        final controller = GuardAiController(repository);
        addTearDown(controller.dispose);
        await _start(tester, controller, scale: scale);
        final field = find.byType(TextField, skipOffstage: false);
        await _reveal(tester, field);
        await tester.enterText(field, 'Texto de prueba');
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        final send = find.byKey(
          const Key('guard-ai-send'),
          skipOffstage: false,
        );
        await _reveal(tester, send);
        await tester.tap(send);
        await tester.pump();

        expect(tester.widget<IconButton>(send).onPressed, isNull);
        expect(find.text('Thinking…'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton &&
                      widget.tooltip == 'Ayuda de GuardAI',
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(GuardAiPage), findsOneWidget);
        repository.pending.completeError(StateError('fallo de ejemplo'));
        await tester.pumpAndSettle();

        expect(controller.conversation.messages, hasLength(161));
        expect(controller.draft, 'Texto de prueba');
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
        expect(
          tester
              .getRect(find.byKey(const Key('guard-ai-composer-scroll')))
              .overlaps(tester.getRect(field)),
          isTrue,
        );
        expect(
          find.byKey(const Key('guard-ai-error'), skipOffstage: false),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        repository.pending = Completer<GuardAiConversation>();
        await _reveal(tester, send);
        await tester.tap(send);
        await tester.pump();
        repository.completeReply();
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();

        final latest = find.byKey(
          const ValueKey('guard-ai-message-162'),
          skipOffstage: false,
        );
        expect(controller.conversation.messages, hasLength(163));
        expect(controller.error, isNull);
        expect(find.text('Thinking…'), findsNothing);
        expect(controller.draft, isEmpty);
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
        expect(latest, findsOneWidget);
        final replyBounds = tester.getRect(latest);
        expect(replyBounds.top, greaterThanOrEqualTo(_viewport(tester).top));
        if (replyBounds.height <= _viewport(tester).height) {
          expect(
            replyBounds.bottom,
            lessThanOrEqualTo(_viewport(tester).bottom),
          );
        } else {
          expect(_viewport(tester).overlaps(replyBounds), isTrue);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final useWheel in [false, true]) {
    testWidgets('manual scroll stays free after a reply (wheel: $useWheel)', (
      tester,
    ) async {
      final repository = _LongHistoryRepository();
      final controller = GuardAiController(repository);
      addTearDown(controller.dispose);
      await _start(tester, controller);
      await tester.enterText(find.byType(TextField), 'Continuar');
      await tester.tap(find.byKey(const Key('guard-ai-send')));
      await tester.pump();
      repository.completeReply();
      await tester.pumpAndSettle();
      final viewport = find.byKey(const Key('guard-ai-scroll'));
      final scrollable = find
          .descendant(of: viewport, matching: find.byType(Scrollable))
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      final latestOffset = position.pixels;
      for (var i = 0; i < 3; i++) {
        if (useWheel) {
          await tester.sendEventToBinding(
            PointerScrollEvent(
              position: tester.getCenter(viewport),
              scrollDelta: const Offset(0, -400),
              kind: PointerDeviceKind.mouse,
            ),
          );
        } else {
          await tester.drag(viewport, const Offset(0, 400));
        }
        await tester.pumpAndSettle();
      }
      expect(position.pixels, lessThan(latestOffset - 300));
      // A viewport change must not pull someone reading older turns to the end.
      tester.view.physicalSize = const Size(390, 814);
      await tester.pumpAndSettle();
      expect(position.pixels, lessThan(latestOffset - 300));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'switching the page controller detaches the prior history listener',
    (tester) async {
      final first = _ListenerAwareController(_LongHistoryRepository());
      final second = _ListenerAwareController(_LongHistoryRepository());
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await _start(tester, first);
      second.setDraft('Borrador de otra sesión');
      await _start(tester, second);
      expect(first.hasActiveListeners, isFalse);
      expect(second.hasActiveListeners, isTrue);
      final field = find.byType(TextField, skipOffstage: false);
      await _reveal(tester, field);

      first.setDraft('Texto de la sesión anterior');
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(field).controller!.text,
        'Borrador de otra sesión',
      );
      await tester.pumpWidget(const SizedBox());
      expect(second.hasActiveListeners, isFalse);
      second.setDraft('Texto tras cerrar');
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}

bool _isMessage(Widget widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('guard-ai-message-');
}

Rect _viewport(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('guard-ai-scroll')));

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 4; attempt++) {
    await Scrollable.ensureVisible(tester.element(finder));
    await tester.pumpAndSettle();
    if (finder.hitTestable().evaluate().isNotEmpty) return;
  }
  expect(finder.hitTestable(), findsOneWidget);
}

Future<void> _start(
  WidgetTester tester,
  GuardAiController controller, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(320, 640);
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

class _ListenerAwareController extends GuardAiController {
  _ListenerAwareController(super.repository);

  bool get hasActiveListeners => hasListeners;
}

class _LongHistoryRepository implements GuardAiRepository {
  var pending = Completer<GuardAiConversation>();
  GuardAiInput? _input;
  var _conversation = GuardAiConversation(
    messages: List.generate(
      161,
      (index) => GuardAiMessage(
        role: index.isEven ? GuardAiRole.assistant : GuardAiRole.person,
        text:
            'Turno ficticio $index. ${'Revisamos el ejemplo. ' * (index % 4 + 1)}',
      ),
    ),
  );

  @override
  Future<GuardAiConversation> loadConversation() async => _conversation;

  @override
  Future<GuardAiConversation> reply(GuardAiInput input) {
    _input = input;
    return pending.future;
  }

  void completeReply() {
    _conversation = GuardAiConversation(
      messages: [
        ..._conversation.messages,
        GuardAiMessage(role: GuardAiRole.person, text: _input!.text),
        const GuardAiMessage(
          role: GuardAiRole.assistant,
          text: 'Respuesta final visible.',
        ),
      ],
    );
    pending.complete(_conversation);
  }
}
