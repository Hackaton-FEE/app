import '../domain/guard_ai_repository.dart';
import '../domain/guard_ai_quick_prompt.dart';
import 'assistant_client.dart';
import '../../footprint/domain/footprint_profile.dart';
import 'guard_ai_report_context.dart';

/// Conecta GuardAI con `POST /api/v1/assistant/chat`. El servidor no
/// persiste la conversación: cada turno reenvía el historial completo, así
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
    final String text;
    try {
      text = await _client.chat([
        for (final message in pending.take(pending.length - 1))
          {
            'role': message.role == GuardAiRole.person ? 'user' : 'assistant',
            'content': message.text,
          },
        if (currentProfile != null)
          {'role': 'user', 'content': guardAiReportContext(profile)},
        {'role': 'user', 'content': input.text},
      ]);
    } on AssistantChatRejected catch (rejection) {
      // El servidor solo emite este código cuando el asistente está
      // apagado por configuración, no ante un fallo transitorio del
      // proveedor: es el único caso en que GuardAI está realmente
      // "desconectado" desde la perspectiva del cliente.
      if (rejection.code == 'assistant-unavailable') {
        throw const GuardAiUnavailable();
      }
      rethrow;
    }
    _messages = [
      ...pending,
      GuardAiMessage(
        role: GuardAiRole.assistant,
        text: text,
        recommendedAction:
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
}
