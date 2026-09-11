import 'dart:async';
import 'dart:convert';

import 'package:fee_app/features/guard_ai/data/assistant_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.StreamedResponse _sseResponse(
  List<String> events, {
  int statusCode = 200,
}) {
  final bytes = utf8.encode(events.join());
  return http.StreamedResponse(
    Stream.value(bytes),
    statusCode,
    headers: {'content-type': 'text/event-stream'},
  );
}

String _event(String name, Map<String, dynamic> data) =>
    'event: $name\ndata: ${jsonEncode(data)}\n\n';

void main() {
  group('AssistantClient.chat', () {
    test('accumulates token events and stops at done', () async {
      final client = AssistantClient(
        httpClient: MockClient.streaming((request, bodyStream) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/assistant/chat');
          expect(request.headers['Authorization'], 'Bearer test-jwt');
          final body = jsonDecode(await bodyStream.bytesToString());
          expect(body['messages'], [
            {'role': 'user', 'content': 'hola'},
          ]);
          return _sseResponse([
            _event('token', {'content': 'Hola, '}),
            _event('token', {'content': 'soy GuardAI.'}),
            _event('done', {}),
          ]);
        }),
        tokenProvider: () => 'test-jwt',
      );

      final reply = await client.chat([
        {'role': 'user', 'content': 'hola'},
      ]);

      expect(reply, 'Hola, soy GuardAI.');
    });

    test('an error event surfaces as AssistantChatFailure', () async {
      final client = AssistantClient(
        httpClient: MockClient.streaming(
          (request, _) async => _sseResponse([
            _event('token', {'content': 'a medias'}),
            _event('error', {'detail': 'assistant-unavailable'}),
          ]),
        ),
        tokenProvider: () => 'test-jwt',
      );

      await expectLater(
        client.chat([
          {'role': 'user', 'content': 'hola'},
        ]),
        throwsA(isA<AssistantChatFailure>()),
      );
    });

    test(
      'returns completed text even when the connection stays open',
      () async {
        final stream = StreamController<List<int>>();
        final client = AssistantClient(
          httpClient: MockClient.streaming(
            (request, _) async => http.StreamedResponse(stream.stream, 200),
          ),
        );
        stream.add(
          utf8.encode(
            _event('token', {'content': 'Respuesta completa.'}) +
                _event('done', {}),
          ),
        );
        try {
          expect(
            await client
                .chat([
                  {'role': 'user', 'content': 'hola'},
                ])
                .timeout(const Duration(seconds: 1)),
            'Respuesta completa.',
          );
          expect(stream.hasListener, isFalse);
        } finally {
          await stream.close();
        }
      },
    );

    test('blank provider output is a generation failure', () async {
      final client = AssistantClient(
        httpClient: MockClient.streaming(
          (request, _) async => _sseResponse([
            _event('token', {'content': '  \n '}),
            _event('done', {}),
          ]),
        ),
      );
      await expectLater(
        client.chat([
          {'role': 'user', 'content': 'hola'},
        ]),
        throwsA(isA<AssistantChatFailure>()),
      );
    });

    test(
      'keeps HTTP status when the error body is not a problem document',
      () async {
        final client = AssistantClient(
          httpClient: MockClient.streaming(
            (request, _) async =>
                _sseResponse(['bad gateway'], statusCode: 502),
          ),
        );
        await expectLater(
          client.chat([
            {'role': 'user', 'content': 'hola'},
          ]),
          throwsA(
            isA<AssistantChatRejected>().having(
              (error) => error.statusCode,
              'statusCode',
              502,
            ),
          ),
        );
      },
    );

    test('a 503 before streaming surfaces as AssistantChatRejected', () async {
      final client = AssistantClient(
        httpClient: MockClient.streaming(
          (request, _) async => http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode({
                  'type': 'https://fee/errors/assistant-unavailable',
                  'detail': 'El asistente no está disponible en este momento.',
                }),
              ),
            ),
            503,
          ),
        ),
        tokenProvider: () => 'test-jwt',
      );

      await expectLater(
        client.chat([
          {'role': 'user', 'content': 'hola'},
        ]),
        throwsA(
          isA<AssistantChatRejected>().having(
            (e) => e.code,
            'code',
            'assistant-unavailable',
          ),
        ),
      );
    });

    test('retries once with a refreshed token after a 401', () async {
      var attempts = 0;
      final client = AssistantClient(
        httpClient: MockClient.streaming((request, _) async {
          attempts++;
          if (attempts == 1) {
            expect(request.headers['Authorization'], 'Bearer stale');
            return http.StreamedResponse(const Stream.empty(), 401);
          }
          expect(request.headers['Authorization'], 'Bearer fresh');
          return _sseResponse([
            _event('token', {'content': 'ok'}),
            _event('done', {}),
          ]);
        }),
        tokenProvider: () => 'stale',
        asyncTokenProvider: ({forceRefresh = false}) async =>
            forceRefresh ? 'fresh' : 'stale',
      );

      final reply = await client.chat([
        {'role': 'user', 'content': 'hola'},
      ]);

      expect(reply, 'ok');
      expect(attempts, 2);
    });
  });
}
