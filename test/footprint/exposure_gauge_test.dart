import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:fee_app/features/footprint/presentation/widgets/exposure_gauge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an unscanned identity has no measured score or risk counts', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExposureGauge(
            profile: FootprintProfile.initial(targetIdentity: ''),
          ),
        ),
      ),
    );
    expect(find.text('—'), findsOneWidget);
    expect(find.text('/100'), findsNothing);
    expect(find.text('0 alta'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      find.bySemanticsLabel('Índice de exposición: sin auditar'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
