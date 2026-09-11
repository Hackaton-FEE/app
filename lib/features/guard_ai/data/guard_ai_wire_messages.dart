import 'dart:convert';

import '../domain/guard_ai_repository.dart';

/// Mantiene la consulta y el informe actual, y añade turnos recientes completos
/// hasta las cotas HTTP. El historial visible no se modifica.
List<Map<String, String>> guardAiWireMessages({
  required List<GuardAiMessage> history,
  required String input,
  String? reportContext,
}) {
  final messages = [
    if (reportContext != null) {'role': 'user', 'content': reportContext},
    {'role': 'user', 'content': input},
  ];
  if (messages.any((m) => m['content']!.runes.length > 4000) ||
      _bodyBytes(messages) > 16000) {
    throw const FormatException('Acorta el mensaje para poder enviarlo.');
  }
  for (
    var end = history.length;
    end >= 2 && messages.length + 2 <= 20;
    end -= 2
  ) {
    final pair = [
      for (final message in history.sublist(end - 2, end))
        {
          'role': message.role == GuardAiRole.person ? 'user' : 'assistant',
          'content': String.fromCharCodes(message.text.runes.take(4000)),
        },
    ];
    if (_bodyBytes([...pair, ...messages]) > 16000) break;
    messages.insertAll(0, pair);
  }
  return messages;
}

int _bodyBytes(List<Map<String, String>> messages) =>
    utf8.encode(jsonEncode({'messages': messages})).length;
