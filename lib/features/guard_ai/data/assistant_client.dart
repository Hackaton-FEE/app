import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fallo al consumir el stream SSE de `/assistant/chat` (proveedor caído a
/// mitad de una respuesta ya iniciada, o error de conexión).
class AssistantChatFailure implements Exception {
  const AssistantChatFailure(this.message);
  final String message;
}

/// El servidor devolvió un error RFC 7807 antes de abrir el stream
/// (sesión inválida, conversación fuera de los límites, o asistente
/// deshabilitado/no disponible).
class AssistantChatRejected implements Exception {
  const AssistantChatRejected({
    required this.code,
    required this.message,
    this.statusCode,
  });
  final String? code;
  final String message;
  final int? statusCode;
}

typedef AssistantAsyncTokenProvider = Future<String?> Function({
  bool forceRefresh,
});

/// Cliente HTTP para `POST /api/v1/assistant/chat`: reenvía el historial de
/// la conversación en cada petición (el servidor no persiste nada) y
/// consume la respuesta por Server-Sent Events a medida que llega.
class AssistantClient {
  AssistantClient({
    this.baseUrl = 'https://backosisnt.ici-labs.com/api/v1',
    String? Function()? tokenProvider,
    this._asyncTokenProvider,
    http.Client? httpClient,
  }) : _tokenProvider = tokenProvider ?? (() => null),
       _client = httpClient ?? http.Client();

  final String baseUrl;
  final String? Function() _tokenProvider;
  final AssistantAsyncTokenProvider? _asyncTokenProvider;
  final http.Client _client;

  static const _connectTimeout = Duration(seconds: 15);
  // Se reinicia con cada línea recibida: protege contra un proveedor que
  // abre el stream y luego se queda callado sin cerrar la conexión, sin
  // limitar la duración total de una respuesta larga que sigue avanzando.
  static const _streamIdleTimeout = Duration(seconds: 40);

  Future<Map<String, String>> _headers({bool forceRefresh = false}) async {
    var token = forceRefresh ? '' : (_tokenProvider() ?? '').trim();
    if (token.isEmpty && _asyncTokenProvider != null) {
      final ensured = await _asyncTokenProvider(forceRefresh: forceRefresh);
      if (ensured != null && ensured.trim().isNotEmpty) token = ensured.trim();
    }
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'text/event-stream',
      'User-Agent': 'fee_app/0.1.0',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Envía el historial completo y devuelve el texto de la respuesta del
  /// asistente, reconstruido a partir de los fragmentos `token` del stream.
  Future<String> chat(List<Map<String, String>> messages) async {
    var response = await _open(messages, await _headers());
    if (response.statusCode == 401 && _asyncTokenProvider != null) {
      response = await _open(messages, await _headers(forceRefresh: true));
    }
    if (response.statusCode != 200) {
      throw await _rejectionFor(response);
    }
    return _consume(response);
  }

  Future<http.StreamedResponse> _open(
    List<Map<String, String>> messages,
    Map<String, String> headers,
  ) {
    final request = http.Request('POST', Uri.parse('$baseUrl/assistant/chat'))
      ..headers.addAll(headers)
      ..body = jsonEncode({'messages': messages});
    return _client.send(request).timeout(_connectTimeout);
  }

  Future<AssistantChatRejected> _rejectionFor(
    http.StreamedResponse response,
  ) async {
    String? code;
    try {
      final body = await response.stream.bytesToString().timeout(
        _connectTimeout,
      );
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type'];
        if (type is String) code = type.split('/').last;
      }
    } catch (_) {
      // application/problem+json esperado; si no llega, usamos el estado HTTP.
    }
    final message = switch (response.statusCode) {
      400 || 422 => 'Ese mensaje no se pudo enviar. Revisa la conversación.',
      401 => 'Tu sesión ha caducado. Vuelve a iniciar sesión.',
      429 => 'Demasiadas preguntas seguidas. Espera un momento.',
      503 => 'GuardAI no está disponible en este momento.',
      _ => 'No se pudo contactar con GuardAI.',
    };
    return AssistantChatRejected(
      code: code,
      message: message,
      statusCode: response.statusCode,
    );
  }

  Future<String> _consume(http.StreamedResponse response) async {
    final buffer = StringBuffer();
    var eventName = '';
    var sawDone = false;

    void handleLine(String line) {
      if (line.isEmpty) {
        eventName = '';
        return;
      }
      if (line.startsWith('event: ')) {
        eventName = line.substring('event: '.length).trim();
        return;
      }
      if (!line.startsWith('data: ')) return;
      final data = jsonDecode(line.substring('data: '.length));
      switch (eventName) {
        case 'token':
          if (data is Map<String, dynamic> && data['content'] is String) {
            buffer.write(data['content'] as String);
          }
          break;
        case 'done':
          sawDone = true;
          break;
        case 'error':
          final detail = data is Map<String, dynamic>
              ? data['detail'] as String?
              : null;
          throw AssistantChatFailure(
            detail == 'assistant-unavailable'
                ? 'GuardAI perdió la conexión con el proveedor. Inténtalo de nuevo.'
                : 'GuardAI no pudo terminar la respuesta.',
          );
      }
    }

    try {
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(_streamIdleTimeout)) {
        handleLine(line);
        if (sawDone) break;
      }
    } on AssistantChatFailure {
      rethrow;
    } catch (_) {
      throw const AssistantChatFailure(
        'Se perdió la conexión con GuardAI. Inténtalo de nuevo.',
      );
    }

    if (!sawDone || buffer.toString().trim().isEmpty) {
      throw const AssistantChatFailure(
        'GuardAI no devolvió una respuesta completa. Inténtalo de nuevo.',
      );
    }
    return buffer.toString();
  }
}
