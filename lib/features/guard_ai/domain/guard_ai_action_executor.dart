/// One executor is owned by one process. Cancellation must release pending work.
abstract interface class GuardAiActionExecutor {
  Future<void> runStep(int step, String action);
  void cancel();
}

class GuardAiActionCancelled implements Exception {
  const GuardAiActionCancelled();
}

enum GuardAiStepStatus { pending, running, completed, failed }

enum GuardAiProcessStatus { ready, running, completed, failed, cancelled }

class GuardAiProcessStep {
  const GuardAiProcessStep(this.title, this.description);
  final String title;
  final String description;
}

const guardAiProcessSteps = [
  GuardAiProcessStep('Preparar', 'Revisar la solicitud y su contexto.'),
  GuardAiProcessStep('Procesar', 'Realizar la acción seleccionada.'),
  GuardAiProcessStep('Verificar', 'Comprobar el resultado del proceso.'),
];
