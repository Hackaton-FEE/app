import '../domain/guard_ai_repository.dart';

/// Empty until a backend adapter is supplied. Never fabricates a reply.
class UnavailableGuardAiRepository implements GuardAiRepository {
  const UnavailableGuardAiRepository();

  @override
  Future<GuardAiConversation> loadConversation() async => GuardAiConversation();

  @override
  Future<GuardAiConversation> reply(GuardAiInput input) async {
    throw const GuardAiUnavailable();
  }
}
