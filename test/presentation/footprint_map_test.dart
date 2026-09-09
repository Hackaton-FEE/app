import 'package:fee_app/features/footprint/domain/footprint_item.dart';
import 'package:fee_app/features/footprint/presentation/widgets/footprint_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FootprintItem _item(String id, FootprintCategory category) => FootprintItem(
  id: id,
  platform: 'Servicio de ejemplo',
  category: category,
  riskLevel: FootprintRisk.low,
  title: 'Perfil de ejemplo',
  description: 'Descripción de ejemplo',
  exposedData: const ['Alias'],
  sourceUrl: 'https://example.com',
  recommendedAction: 'Revisar el perfil',
);

void main() {
  for (final size in [const Size(390, 844), const Size(320, 844)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'category map remains usable at ${size.width}px and ${scale}x text',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          final selected = <FootprintCategory>[];

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: FootprintMap(
                      items: [
                        _item('social-1', FootprintCategory.socialProfile),
                        _item('social-2', FootprintCategory.socialProfile),
                        _item('broker', FootprintCategory.dataBroker),
                      ],
                      onCategorySelected: selected.add,
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.bySemanticsLabel('Redes, 2 hallazgos'), findsOneWidget);
          expect(
            find.bySemanticsLabel('Contacto, 0 hallazgos'),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel('Directorios, 1 hallazgo'),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel('Filtraciones, 0 hallazgos'),
            findsOneWidget,
          );

          for (final category in FootprintCategory.values) {
            final button = find.byKey(
              ValueKey('footprint-map-${category.name}'),
            );
            await tester.ensureVisible(button);
            await tester.tap(button);
          }

          expect(selected, FootprintCategory.values);
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byType(FootprintMap)).width,
            size.width - 32,
          );
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
        },
      );
    }
  }
}
