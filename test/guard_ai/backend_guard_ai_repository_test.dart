import 'dart:convert';

import 'package:fee_app/features/guard_ai/data/assistant_client.dart';
import 'package:fee_app/features/guard_ai/data/backend_guard_ai_repository.dart';
import 'package:fee_app/features/guard_ai/domain/guard_ai_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _event(String name, Map<String, dynamic> data) =>
    'event: $name\ndata: ${jsonEncode(data)}\n\n';

void main() {
  group('BackendGuardAiRepository', () {
    test('starts empty and appends both turns after a reply', () async {
      final repository = BackendGuardAiRepository(
        client: AssistantClient(
          httpClient: MockClient.streaming(
            (request, _) async => http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  _event('token', {'content': 'Reduce tu huella digital.'}) +
                      _event('done', {}),
                ),
              ),
              200,
            ),
          ),
        ),
      );

      expect((await repository.loadConversation()).messages, isEmpty);

      final conversation = await repository.reply(
        GuardAiInput('¿Cómo protejo mi privacidad?'),
      );

      expect(conversation.messages, hasLength(2));
      expect(conversation.messages.first.role, GuardAiRole.person);
      expect(conversation.messages.last.role, GuardAiRole.assistant);
      expect(conversation.messages.last.text, 'Reduce tu huella digital.');
    });

    test('resends the whole history on the next turn', () async {
      final seenRequests = <List<dynamic>>[];
      var callCount = 0;
      final repository = BackendGuardAiRepository(
        client: AssistantClient(
          httpClient: MockClient.streaming((request, bodyStream) async {
            callCount++;
            final body = jsonDecode(
              await bodyStream.bytesToString(),
            ) as Map<String, dynamic>;
            seenRequests.add(body['messages'] as List<dynamic>);
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  _event('token', {'content': 'respuesta $callCount'}) +
                      _event('done', {}),
                ),
              ),
              200,
            );
          }),
        ),
      );

      await repository.reply(GuardAiInput('primer mensaje'));
      await repository.reply(GuardAiInput('segundo mensaje'));

      expect(seenRequests[0], hasLength(1));
      expect(seenRequests[1], hasLength(3));
      expect(seenRequests[1].last, {
        'role': 'user',
        'content': 'segundo mensaje',
      });
    });

    test(
      'leaves the conversation unchanged when the assistant is disabled',
      () async {
        final repository = BackendGuardAiRepository(
          client: AssistantClient(
            httpClient: MockClient.streaming(
              (request, _) async => http.StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'type': 'https://fee/errors/assistant-unavailable',
                    }),
                  ),
                ),
                503,
              ),
            ),
          ),
        );

        await expectLater(
          repository.reply(GuardAiInput('hola')),
          throwsA(isA<GuardAiUnavailable>()),
        );
        expect((await repository.loadConversation()).messages, isEmpty);
      },
    );
  });
}
