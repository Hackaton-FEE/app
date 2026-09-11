import 'package:flutter/foundation.dart';

import '../domain/guard_ai_action_executor.dart';

class GuardAiProcessController extends ChangeNotifier {
  GuardAiProcessController({required this.action, required this.executor});

  final String action;
  final GuardAiActionExecutor executor;
  final _steps = List.filled(
    guardAiProcessSteps.length,
    GuardAiStepStatus.pending,
  );
  GuardAiProcessStatus _status = GuardAiProcessStatus.ready;
  int? _failedStep;
  bool _disposed = false;

  List<GuardAiStepStatus> get steps => List.unmodifiable(_steps);
  GuardAiProcessStatus get status => _status;
  int? get failedStep => _failedStep;

  Future<void> start() async {
    if (_disposed || _status != GuardAiProcessStatus.ready) return;
    _status = GuardAiProcessStatus.running;
    for (var i = 0; i < _steps.length; i++) {
      _steps[i] = GuardAiStepStatus.running;
      notifyListeners();
      try {
        await executor.runStep(i, action);
      } catch (_) {
        if (_disposed || _status == GuardAiProcessStatus.cancelled) return;
        _steps[i] = GuardAiStepStatus.failed;
        _failedStep = i;
        _status = GuardAiProcessStatus.failed;
        notifyListeners();
        return;
      }
      if (_disposed || _status == GuardAiProcessStatus.cancelled) return;
      _steps[i] = GuardAiStepStatus.completed;
    }
    _status = GuardAiProcessStatus.completed;
    notifyListeners();
  }

  void cancel() {
    if (_disposed ||
        (_status != GuardAiProcessStatus.running &&
            _status != GuardAiProcessStatus.ready)) {
      return;
    }
    _status = GuardAiProcessStatus.cancelled;
    executor.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    executor.cancel();
    super.dispose();
  }
}
