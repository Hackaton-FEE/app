import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/auth/data/auth_api_client.dart';
import 'package:fee_app/features/footprint/domain/footprint_item.dart';
import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:fee_app/features/guard_ai/data/assistant_client.dart';
import 'package:fee_app/features/guard_ai/data/backend_guard_ai_repository.dart';
import 'package:fee_app/features/guard_ai/data/guard_ai_fallback.dart';
import 'package:fee_app/features/guard_ai/data/guard_ai_wire_messages.dart';
import 'package:fee_app/features/guard_ai/domain/guard_ai_repository.dart';
import 'package:fee_app/features/guard_ai/domain/guard_ai_quick_prompt.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_controller.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _Client extends AssistantClient {
  _Client(this.reply);
  final Future<String> Function(List<Map<String, String>>) reply;
  @override
  Future<String> chat(List<Map<String, String>> messages) => reply(messages);
}

void main() {
  for (final entry in {
    'CONTRASEÑAS y 2FA': 'gestor',
    'contrase\u0301nas': 'gestor',
    'contrasen\u0303a': 'gestor',
    'estafa por correo': 'otro canal',
    'eliminar mi cuenta': 'Antes de borrar',
    'Un PLAN de privacidad': 'tres pasos',
    'Ayúdame con una recomendación': 'coincidencia',
    'HOLA': 'Hola.',
    'plantilla homologada': 'Indícame si tu duda',
    'chocolatería': 'Indícame si tu duda',
  }.entries) {
    test('fallback intent: ${entry.key}', () {
      final reply = guardAiFallback(entry.key);
      expect(reply, startsWith('Orientación general:'));
      expect(reply, contains(entry.value));
    });
  }

  for (final failure in <Object>[
    const AssistantChatFailure('provider failed'),
    TimeoutException('timeout'),
    http.ClientException('offline'),
    const SocketException('offline'),
    const HandshakeException('handshake failed'),
    const AssistantChatRejected(code: null, message: 'busy', statusCode: 429),
    const AssistantChatRejected(
      code: null,
      message: 'unavailable',
      statusCode: 503,
    ),
    const AssistantChatRejected(code: 'assistant-unavailable', message: 'off'),
  ]) {
    test(
      'generation failure ${failure.runtimeType} commits fallback once and recovers',
      () async {
        var calls = 0;
        final sent = <List<Map<String, String>>>[];
        final repository = BackendGuardAiRepository(
          client: _Client((messages) async {
            sent.add(messages);
            if (++calls == 1) throw failure;
            return 'Respuesta personalizada recuperada.';
          }),
        );
        final controller = GuardAiController(repository);
        addTearDown(controller.dispose);
        await controller.load();
        controller.setDraft('Consejos de privacidad');
        expect(await controller.sendDraft(), isTrue);
        expect(controller.error, isNull);
        expect(controller.draft, isEmpty);
        expect(controller.conversation.messages, hasLength(2));
        expect(
          controller.conversation.messages.last.text,
          startsWith('Orientación general:'),
        );
        controller.setDraft('Ahora otra pregunta');
        expect(await controller.sendDraft(), isTrue);
        expect(controller.conversation.messages, hasLength(4));
        expect(
          controller.conversation.messages.last.text,
          'Respuesta personalizada recuperada.',
        );
        expect(sent.last, hasLength(3));
        expect(sent.last[1]['content'], startsWith('Orientación general:'));
        expect(calls, 2);
      },
    );
  }

  for (final failure in <Object>[
    const AuthApiException(message: 'expired', code: 'auth_required'),
    for (final status in [400, 401, 403, 422])
      AssistantChatRejected(
        code: 'request-rejected',
        message: 'rejected',
        statusCode: status,
      ),
    StateError('programming error'),
  ]) {
    test('does not mask ${failure.runtimeType} $failure', () async {
      final repository = BackendGuardAiRepository(
        client: _Client((_) async => throw failure),
      );
      final controller = GuardAiController(repository);
      addTearDown(controller.dispose);
      await controller.load();
      controller.setDraft('Mi consulta');
      expect(await controller.sendDraft(), isFalse);
      expect(controller.error, isNotNull);
      expect(controller.draft, 'Mi consulta');
      expect(controller.conversation.messages, isEmpty);
      expect((await repository.loadConversation()).messages, isEmpty);
    });
  }

  test('empty generation uses general text without carrying report actions or facts', () async {
    final repository = BackendGuardAiRepository(
      currentProfile: () => FootprintProfile(
        targetIdentity: 'private_identifier',
        lastScannedAt: DateTime.utc(2026, 9, 11),
        items: [
          FootprintItem(
            id: 'finding',
            platform: 'private_platform',
            category: FootprintCategory.socialProfile,
            riskLevel: FootprintRisk.high,
            title: 'private_title',
            description: 'private_description',
            exposedData: const ['private_data'],
            sourceUrl: 'https://example.invalid/private',
            recommendedAction: 'private_action',
          ),
        ],
      ),
      client: _Client((_) async => ' \n '),
    );
    final reply = (await repository.reply(
      GuardAiInput(GuardAiQuickPrompt.help),
    )).messages.last;
    expect(reply.text, startsWith('Orientación general:'));
    expect(reply.text, isNot(contains('private_')));
    expect(reply.recommendedAction, isNull);
    expect(reply.profileReport, isNull);
  });

  test(
    'long conversations bound outbound pairs while preserving UI history',
    () async {
      final sent = <List<Map<String, String>>>[];
      final repository = BackendGuardAiRepository(
        currentProfile: () => null,
        client: _Client((messages) async {
          sent.add(messages);
          return 'respuesta';
        }),
      );
      for (var i = 0; i < 25; i++) {
        await repository.reply(GuardAiInput('consulta $i'));
      }
      expect((await repository.loadConversation()).messages, hasLength(50));
      expect(sent.last, hasLength(20));
      expect(sent.last.first['content'], 'consulta 15');
      expect(
        sent.last[sent.last.length - 2]['content'],
        contains('No hay un informe'),
      );
      expect(sent.last.last['content'], 'consulta 24');
      expect(sent.every((messages) => messages.length <= 20), isTrue);
    },
  );

  test('wire budget counts UTF8 and retains newest complete pairs and current context', () {
    final history = <GuardAiMessage>[
      for (var i = 0; i < 12; i++) ...[
        GuardAiMessage(role: GuardAiRole.person, text: 'consulta $i'),
        GuardAiMessage(role: GuardAiRole.assistant, text: '漢' * 1000),
      ],
    ];
    final sent = guardAiWireMessages(
      history: history,
      input: 'Consulta actual',
      reportContext: 'informe_actual',
    );
    expect(
      utf8.encode(jsonEncode({'messages': sent})).length,
      lessThanOrEqualTo(16000),
    );
    expect(sent.length, lessThan(20));
    expect((sent.length - 2).isEven, isTrue);
    expect(sent[sent.length - 4]['content'], 'consulta 11');
    expect(sent[sent.length - 2]['content'], 'informe_actual');
    expect(sent.last['content'], 'Consulta actual');
    expect(history, hasLength(24));
  });

  test('transport clips oversized previous reply but never changes visible original', () {
    final text = 'x' * 6000;
    final history = [
      const GuardAiMessage(role: GuardAiRole.person, text: 'hola'),
      GuardAiMessage(role: GuardAiRole.assistant, text: text),
    ];
    final sent = guardAiWireMessages(history: history, input: 'sigue');
    expect(sent[1]['content']!.runes.length, 4000);
    expect(history.last.text.length, 6000);
    expect(
      () => guardAiWireMessages(history: history, input: 'x' * 4001),
      throwsFormatException,
    );
  });

  testWidgets(
    'generation failure shows useful assistant bubble instead of red error',
    (tester) async {
      final controller = GuardAiController(
        BackendGuardAiRepository(
          client: _Client(
            (_) async => throw const AssistantChatFailure('offline'),
          ),
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: GuardAiPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hola');
      await tester.tap(find.byKey(const Key('guard-ai-send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guard-ai-error')), findsNothing);
      expect(find.textContaining('Orientación general:'), findsOneWidget);
      expect(controller.error, isNull);
      expect(controller.conversation.messages, hasLength(2));
    },
  );
}
