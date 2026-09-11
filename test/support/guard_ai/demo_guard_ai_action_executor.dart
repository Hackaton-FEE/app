import 'dart:async';

import 'package:fee_app/features/guard_ai/domain/guard_ai_action_executor.dart';

/// Local simulation only; never calls an external platform.
class DemoGuardAiActionExecutor implements GuardAiActionExecutor {
  DemoGuardAiActionExecutor({
    this.stepDuration = const Duration(seconds: 1),
    this.failAtStep,
  }) : assert(failAtStep == null || (failAtStep >= 0 && failAtStep < 3));

  final Duration stepDuration;
  final int? failAtStep;
  Timer? _timer;
  Completer<void>? _pending;
  bool _cancelled = false;

  @override
  Future<void> runStep(int step, String action) {
    if (_cancelled) return Future.error(const GuardAiActionCancelled());
    final pending = Completer<void>();
    _pending = pending;
    _timer = Timer(stepDuration, () {
      _pending = null;
      _timer = null;
      if (step == failAtStep) {
        pending.completeError(StateError('No se pudo completar el paso.'));
      } else {
        pending.complete();
      }
    });
    return pending.future;
  }

  @override
  void cancel() {
    _cancelled = true;
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const GuardAiActionCancelled());
    }
  }
}
