import 'dart:async';

import 'package:fee_app/app/theme.dart';

import '../support/guard_ai/demo_guard_ai_action_executor.dart';

import 'package:fee_app/features/guard_ai/domain/guard_ai_action_executor.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_process_controller.dart';
import 'package:fee_app/features/guard_ai/presentation/widgets/guard_ai_action_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ControlledExecutor implements GuardAiActionExecutor {
  final pending = List.generate(3, (_) => Completer<void>());
  final calls = <int>[];
  bool cancelled = false;
  @override
  Future<void> runStep(int step, String action) {
    calls.add(step);
    return pending[step].future;
  }

  @override
  void cancel() => cancelled = true;
}

void main() {
  for (var failedStep = 0; failedStep < 3; failedStep++) {
    test('failure in step $failedStep stops remaining steps', () async {
      final executor = ControlledExecutor();
      final controller = GuardAiProcessController(
        action: 'Acción de prueba',
        executor: executor,
      );
      addTearDown(controller.dispose);
      final running = controller.start();
      await controller.start(); // Duplicate starts do not execute twice.
      for (var i = 0; i < failedStep; i++) {
        executor.pending[i].complete();
        await Future<void>.delayed(Duration.zero);
      }
      executor.pending[failedStep].completeError(
        StateError('Error privado de prueba'),
      );
      await running;
      expect(controller.status, GuardAiProcessStatus.failed);
      expect(controller.failedStep, failedStep);
      expect(executor.calls, List.generate(failedStep + 1, (i) => i));
      expect(controller.steps[failedStep], GuardAiStepStatus.failed);
      expect(
        controller.steps.take(failedStep),
        everyElement(GuardAiStepStatus.completed),
      );
      expect(
        controller.steps.skip(failedStep + 1),
        everyElement(GuardAiStepStatus.pending),
      );
    });

    test('cancelling step $failedStep ignores late completion', () async {
      final executor = ControlledExecutor();
      final controller = GuardAiProcessController(
        action: 'Acción de prueba',
        executor: executor,
      );
      addTearDown(controller.dispose);
      final running = controller.start();
      for (var i = 0; i < failedStep; i++) {
        executor.pending[i].complete();
        await Future<void>.delayed(Duration.zero);
      }
      controller.cancel();
      executor.pending[failedStep].complete();
      await running;
      expect(controller.status, GuardAiProcessStatus.cancelled);
      expect(executor.cancelled, isTrue);
      expect(executor.calls.length, failedStep + 1);
    });
  }

  for (final fail in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'three steps then ${fail ? 'error' : 'success'} at ${scale}x',
        (tester) async {
          final executor = ControlledExecutor();
          String? result;
          await start(tester, executor, scale, (value) => result = value);
          expect(find.text('Proceso'), findsOneWidget);
          final semantics = tester.ensureSemantics();
          try {
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
          } finally {
            semantics.dispose();
          }
          expect(
            find.byKey(const ValueKey('process-step-0-running')),
            findsOneWidget,
          );
          for (var i = 0; i < (fail ? 2 : 3); i++) {
            if (fail && i == 1) {
              executor.pending[i].completeError(StateError('private-details'));
            } else {
              executor.pending[i].complete();
            }
            await tester.pump();
          }
          await tester.pump();
          final stepKey = fail
              ? 'process-step-1-failed'
              : 'process-step-2-completed';
          expect(find.byKey(ValueKey(stepKey)), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 800));
          await tester.pumpAndSettle();
          expect(
            find.byKey(
              Key(fail ? 'guard-ai-process-error' : 'guard-ai-process-success'),
            ),
            findsOneWidget,
          );
          expect(find.textContaining('private-details'), findsNothing);
          final back = find.text('Volver al chat');
          await tester.ensureVisible(back);
          await tester.tap(back);
          await tester.pumpAndSettle();
          expect(find.text('Chat de prueba'), findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing);
          expect(
            result,
            contains(fail ? 'No se pudo completar' : 'correctamente realizada'),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final useBack in [false, true]) {
    testWidgets(
      'cancel with ${useBack ? 'system back' : 'button'} releases demo timer',
      (tester) async {
        String? result;
        await start(
          tester,
          DemoGuardAiActionExecutor(),
          1,
          (value) => result = value,
        );
        if (useBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.text('Cancelar'));
        }
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
        expect(result, contains('cancelado'));
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Chat de prueba'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> start(
  WidgetTester tester,
  GuardAiActionExecutor executor,
  double scale,
  ValueChanged<String?> onResult,
) async {
  tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              const Text('Chat de prueba'),
              TextButton(
                onPressed: () async {
                  onResult(
                    await showDialog<String>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => GuardAiActionDialog(
                        action: 'Revisar la privacidad de mi perfil',
                        executor: executor,
                      ),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Aceptar'));
  await tester.pumpAndSettle();
}
