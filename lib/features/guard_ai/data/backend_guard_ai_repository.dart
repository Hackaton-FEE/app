import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/guard_ai_repository.dart';
import '../domain/guard_ai_quick_prompt.dart';
import 'assistant_client.dart';
import '../../footprint/domain/footprint_profile.dart';
import 'guard_ai_report_context.dart';
import 'guard_ai_fallback.dart';
import 'guard_ai_wire_messages.dart';

/// Conecta GuardAI con `POST /api/v1/assistant/chat`. El servidor no
/// persiste la conversación: cada turno reenvía el historial reciente, así
/// que este repositorio lo conserva en memoria mientras vive la instancia
/// (una por chat, ver `GuardAiController.newChat`).
class BackendGuardAiRepository implements GuardAiRepository {
  BackendGuardAiRepository({required this._client, this.currentProfile});

  final AssistantClient _client;
  final FootprintProfile? Function()? currentProfile;
  List<GuardAiMessage> _messages = const [];

  @override
  Future<GuardAiConversation> loadConversation() async => _snapshot();

  @override
  Future<GuardAiConversation> reply(GuardAiInput input) async {
    final profile = currentProfile?.call();
    final pending = [
      ..._messages,
      GuardAiMessage(role: GuardAiRole.person, text: input.text),
    ];
    String text;
    var usedFallback = false;
    try {
      text = await _client.chat(
        guardAiWireMessages(
          history: _messages,
          input: input.text,
          reportContext: currentProfile != null
              ? guardAiReportContext(profile)
              : null,
        ),
      );
      if (text.trim().isEmpty) {
        throw const AssistantChatFailure('Respuesta vacía.');
      }
    } catch (error) {
      if (!_generationFailed(error)) rethrow;
      text = guardAiFallback(input.text);
      usedFallback = true;
    }
    _messages = [
      ...pending,
      GuardAiMessage(
        role: GuardAiRole.assistant,
        text: text,
        recommendedAction:
            !usedFallback &&
                input.text == GuardAiQuickPrompt.help &&
                profile != null &&
                profile.items.isNotEmpty
            ? profile.items
                  .reduce(
                    (a, b) => a.riskLevel.index >= b.riskLevel.index ? a : b,
                  )
                  .recommendedAction
            : null,
      ),
    ];
    return _snapshot();
  }

  GuardAiConversation _snapshot() =>
      GuardAiConversation(messages: List.of(_messages));

  bool _generationFailed(Object error) {
    if (error is AssistantChatRejected) {
      final status = error.statusCode;
      return status == 429 ||
          (status != null && status >= 500 && status <= 599) ||
          (status == null && error.code == 'assistant-unavailable');
    }
    return error is AssistantChatFailure ||
        error is TimeoutException ||
        error is http.ClientException ||
        error is SocketException ||
        error is TlsException;
  }
}
