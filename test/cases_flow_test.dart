import 'package:fee_app/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'validates, creates and deletes a draft without claiming submission',
    (tester) async {
      await tester.pumpWidget(const FeeApp());
      expect(find.text('Aún no tienes borradores.'), findsOneWidget);
      await tester.tap(find.text('Nuevo borrador'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'not-a-link');
      await tester.tap(find.text('Crear borrador'));
      await tester.pumpAndSettle();
      expect(
        find.text('Introduce un enlace válido con https:// o http://.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextFormField),
        'https://example.com/post',
      );
      await tester.tap(find.text('Crear borrador'));
      await tester.pumpAndSettle();
      expect(find.text('example.com'), findsOneWidget);
      expect(find.text('Borrador · sin enviar'), findsOneWidget);
      expect(find.text('Aún no tienes borradores.'), findsNothing);

      await tester.tap(find.byTooltip('Eliminar borrador'));
      await tester.pumpAndSettle();
      expect(find.text('Aún no tienes borradores.'), findsOneWidget);
    },
  );

  testWidgets('canceling the form creates no draft', (tester) async {
    await tester.pumpWidget(const FeeApp());
    await tester.tap(find.text('Nuevo borrador'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'https://example.com/cancel',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes borradores.'), findsOneWidget);
  });
}
