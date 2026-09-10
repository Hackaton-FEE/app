import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/guard_ai/data/unavailable_guard_ai_repository.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_controller.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unavailable service shows no generated messages or composer', (
    tester,
  ) async {
    final controller = GuardAiController(const UnavailableGuardAiRepository());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: GuardAiPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.isUnavailable, isTrue);
    expect(controller.conversation.messages, isEmpty);
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('guard-ai-send')), findsNothing);
    expect(
      find.textContaining('GuardAI aún no está disponible en el servidor.'),
      findsOneWidget,
    );
    expect(find.text('Volver a abrir el chat'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
