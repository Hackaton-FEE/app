import 'dart:async';

import 'package:fee_app/features/guard_ai/data/demo_guard_ai_repository.dart';
import 'package:fee_app/features/guard_ai/domain/guard_ai_repository.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo follows answers and keeps prior turns', () async {
    final repository = DemoGuardAiRepository();
    final initial = await repository.loadConversation();
    final first = await repository.reply(GuardAiInput('Revisar mis datos'));
    expect(first.messages.last.text, contains('dónde aparecen'));
    final second = await repository.reply(GuardAiInput('En un buscador'));
    expect(second.messages.last.text, contains('página que lo publica'));
    final third = await repository.reply(GuardAiInput('Preparar una lista'));
    expect(third.messages.last.text, contains('Tu lista de revisión'));
    expect(third.messages, hasLength(7));
    expect(initial.messages, hasLength(1));
    expect(first.messages, hasLength(3));
    expect(() => third.messages.clear(), throwsUnsupportedError);
    expect(() => third.suggestions.clear(), throwsUnsupportedError);
    expect(await repository.loadConversation(), same(third));
  });

  test('different profile answers guide the next reply', () async {
    final repository = DemoGuardAiRepository();
    await repository.reply(GuardAiInput('Revisar un perfil'));
    final answer = await repository.reply(
      GuardAiInput('No reconozco el perfil'),
    );
    expect(answer.messages.last.text, contains('no puede confirmar'));
    final restarted = await repository.reply(GuardAiInput('Empezar otro tema'));
    expect(restarted.suggestions, contains('Organizar próximos pasos'));
    final nextTopic = await repository.reply(
      GuardAiInput('Organizar próximos pasos'),
    );
    expect(nextTopic.messages.last.text, contains('lista breve'));
  });

  test(
    'unrecognized queries disclose demo limits and allow recovery',
    () async {
      final repository = DemoGuardAiRepository();
      final answer = await repository.reply(GuardAiInput('Dime el clima'));
      expect(answer.messages.last.text, contains('respuestas predefinidas'));
      expect(answer.suggestions, contains('Revisar mis datos'));
      final next = await repository.reply(GuardAiInput('Revisar mis datos'));
      expect(next.messages.last.text, contains('dónde aparecen'));
    },
  );

  test('draft validation counts graphemes and rejects empty text', () {
    expect(() => GuardAiInput('  '), throwsFormatException);
    expect(GuardAiInput('  hola  ').text, 'hola');
    expect(GuardAiInput('👩🏽‍💻' * 1000).text, isNotEmpty);
    expect(() => GuardAiInput('a' * 1001), throwsFormatException);
  });

  test('waits for repository and rejects duplicate sends', () async {
    final repository = ControlledRepository();
    final controller = GuardAiController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    controller.setDraft('Revisar mis datos');
    final pending = controller.sendDraft();
    expect(controller.isSending, isTrue);
    expect(controller.conversation.messages, hasLength(1));
    expect(controller.draft, 'Revisar mis datos');
    expect(await controller.sendDraft(), isFalse);
    expect(repository.replyCount, 1);
    repository.pending.complete(
      GuardAiConversation(
        messages: const [
          GuardAiMessage(role: GuardAiRole.person, text: 'Revisar mis datos'),
          GuardAiMessage(role: GuardAiRole.assistant, text: 'Siguiente paso'),
        ],
      ),
    );
    expect(await pending, isTrue);
    expect(controller.draft, isEmpty);
    expect(controller.isSending, isFalse);
    expect(controller.conversation.messages.last.text, 'Siguiente paso');
  });

  test('failed reply preserves message and history, then can retry', () async {
    final repository = ControlledRepository();
    final controller = GuardAiController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    final original = controller.conversation;
    controller.setDraft('Texto ficticio');
    final pending = controller.sendDraft();
    repository.pending.completeError(Exception('sensitive.example.invalid'));
    expect(await pending, isFalse);
    expect(controller.draft, 'Texto ficticio');
    expect(controller.conversation, same(original));
    expect(controller.error, contains('puedes volver a intentarlo'));
    expect(controller.error, isNot(contains('sensitive')));
    expect(controller.status, isNull);
    repository.pending = Completer<GuardAiConversation>();
    final retry = controller.sendDraft();
    repository.pending.complete(original);
    expect(await retry, isTrue);
    expect(controller.error, isNull);
  });

  test(
    'load failure is recoverable without treating it as an empty chat',
    () async {
      final repository = ControlledRepository()..failLoad = true;
      final controller = GuardAiController(repository);
      addTearDown(controller.dispose);
      controller.setDraft('Un borrador');
      await controller.load();
      expect(controller.isReady, isFalse);
      expect(controller.error, isNotNull);
      expect(controller.draft, 'Un borrador');
      expect(await controller.sendDraft(), isFalse);
      expect(repository.replyCount, 0);
      repository.failLoad = false;
      await controller.load();
      expect(controller.isReady, isTrue);
      expect(controller.conversation.messages, hasLength(1));
      await controller.load();
      expect(repository.loadCount, 2);
    },
  );

  test('invalid draft never reaches repository and is retained', () async {
    final repository = ControlledRepository();
    final controller = GuardAiController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    controller.setDraft('  ');
    expect(await controller.sendDraft(), isFalse);
    expect(controller.error, contains('Escribe un mensaje'));
    controller.setDraft('a' * 1001);
    expect(await controller.sendDraft(), isFalse);
    expect(controller.error, contains('1000 caracteres'));
    expect(controller.draft, hasLength(1001));
    expect(repository.replyCount, 0);
  });

  test(
    'disposing during a reply does not notify a disposed controller',
    () async {
      final repository = ControlledRepository();
      final controller = GuardAiController(repository);
      await controller.load();
      controller.setDraft('Un mensaje');
      final pending = controller.sendDraft();
      controller.dispose();
      repository.pending.complete(GuardAiConversation());
      expect(await pending, isFalse);
    },
  );
}

class ControlledRepository implements GuardAiRepository {
  var pending = Completer<GuardAiConversation>();
  bool failLoad = false;
  int loadCount = 0;
  int replyCount = 0;

  @override
  Future<GuardAiConversation> loadConversation() async {
    loadCount++;
    if (failLoad) throw Exception('No disponible');
    return GuardAiConversation(
      messages: const [
        GuardAiMessage(role: GuardAiRole.assistant, text: 'Hola'),
      ],
    );
  }

  @override
  Future<GuardAiConversation> reply(GuardAiInput input) {
    replyCount++;
    return pending.future;
  }
}
