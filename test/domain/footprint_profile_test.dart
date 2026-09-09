import 'package:fee_app/features/footprint/domain/footprint_item.dart';
import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FootprintProfile', () {
    test('calculates exposure score and counts correctly', () {
      final profile = FootprintProfile(
        targetIdentity: 'test@example.com',
        lastScannedAt: DateTime.now(),
        items: [
          FootprintItem(
            id: '1',
            platform: 'Platform A',
            category: FootprintCategory.dataBroker,
            riskLevel: FootprintRisk.high,
            title: 'High risk title',
            description: 'Desc',
            exposedData: ['Email'],
            sourceUrl: 'https://example.com/1',
            recommendedAction: 'Action 1',
          ),
          FootprintItem(
            id: '2',
            platform: 'Platform B',
            category: FootprintCategory.socialProfile,
            riskLevel: FootprintRisk.medium,
            title: 'Med risk title',
            description: 'Desc',
            exposedData: ['Username'],
            sourceUrl: 'https://example.com/2',
            recommendedAction: 'Action 2',
          ),
          FootprintItem(
            id: '3',
            platform: 'Platform C',
            category: FootprintCategory.exposedContact,
            riskLevel: FootprintRisk.low,
            title: 'Low risk title',
            description: 'Desc',
            exposedData: ['Name'],
            sourceUrl: 'https://example.com/3',
            recommendedAction: 'Action 3',
          ),
        ],
      );

      expect(profile.highRiskCount, 1);
      expect(profile.mediumRiskCount, 1);
      expect(profile.lowRiskCount, 1);
      // 28 + 15 + 6 = 49
      expect(profile.exposureScore, 49);
      expect(profile.overallRisk, FootprintRisk.high);
    });

    test('empty items produces low risk default', () {
      final profile = FootprintProfile(
        targetIdentity: 'clean@example.com',
        lastScannedAt: DateTime.now(),
        items: const [],
      );

      expect(profile.exposureScore, 10);
      expect(profile.highRiskCount, 0);
      expect(profile.overallRisk, FootprintRisk.low);
    });

    test('copies the input list and exposes an immutable snapshot', () {
      final items = [
        _item(['Correo']),
      ];
      final profile = FootprintProfile(
        targetIdentity: 'ejemplo@example.invalid',
        lastScannedAt: DateTime(2026),
        items: items,
      );

      items.clear();

      expect(profile.items, hasLength(1));
      expect(profile.exposureScore, 28);
      expect(() => profile.items.clear(), throwsUnsupportedError);
      expect(() => profile.items[0] = _item([]), throwsUnsupportedError);
    });

    test('an item copies exposed data and rejects later mutations', () {
      final exposedData = ['Correo'];
      final item = _item(exposedData);

      exposedData.add('Teléfono');

      expect(item.exposedData, ['Correo']);
      expect(() => item.exposedData.add('Nombre'), throwsUnsupportedError);
      expect(() => item.exposedData[0] = 'Nombre', throwsUnsupportedError);
    });
  });
}

FootprintItem _item(List<String> exposedData) => FootprintItem(
  id: 'example',
  platform: 'Plataforma de ejemplo',
  category: FootprintCategory.dataBroker,
  riskLevel: FootprintRisk.high,
  title: 'Hallazgo de ejemplo',
  description: 'Datos simulados',
  exposedData: exposedData,
  sourceUrl: 'https://example.invalid',
  recommendedAction: 'Revisar el ejemplo',
);
