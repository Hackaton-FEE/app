import '../domain/guard_ai_action_executor.dart';

/// Actions require an injected executor that confirms actual completion.
class UnavailableGuardAiActionExecutor implements GuardAiActionExecutor {
  @override
  Future<void> runStep(int step, String action) async {
    throw StateError('La ejecución de acciones no está conectada.');
  }

  @override
  void cancel() {}
}
