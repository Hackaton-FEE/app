import '../domain/guard_ai_repository.dart';

/// No chat route exists in the deployed API yet.
class UnavailableGuardAiRepository implements GuardAiRepository {
  const UnavailableGuardAiRepository();

  @override
  Future<GuardAiConversation> loadConversation() async =>
      throw const GuardAiUnavailableException();

  @override
  Future<GuardAiConversation> reply(GuardAiInput input) async =>
      throw const GuardAiUnavailableException();
}
