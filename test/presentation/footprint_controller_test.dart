import 'package:fee_app/features/footprint/data/mock_footprint_repository.dart';
import 'package:fee_app/features/footprint/domain/footprint_item.dart';
import 'package:fee_app/features/footprint/presentation/footprint_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FootprintController', () {
    late MockFootprintRepository repository;
    late FootprintController controller;

    setUp(() {
      repository = MockFootprintRepository();
      controller = FootprintController(repository);
    });

    tearDown(() {
      controller.dispose();
    });

    test('loadProfile updates profile and resets loading state', () async {
      expect(controller.profile, isNull);
      await controller.loadProfile();
      expect(controller.profile, isNotNull);
      expect(controller.profile!.items, isNotEmpty);
      expect(controller.isLoading, isFalse);
    });

    test('filter by category updates visibleItems', () async {
      await controller.loadProfile();
      final totalCount = controller.visibleItems.length;

      controller.setCategoryFilter(FootprintCategory.dataBroker);
      expect(controller.selectedCategory, FootprintCategory.dataBroker);
      expect(
        controller.visibleItems.every(
          (it) => it.category == FootprintCategory.dataBroker,
        ),
        isTrue,
      );

      // Toggling same filter resets it
      controller.setCategoryFilter(FootprintCategory.dataBroker);
      expect(controller.selectedCategory, isNull);
      expect(controller.visibleItems.length, totalCount);
    });

    test(
      'visible items cannot mutate the repository with or without a filter',
      () async {
        await controller.loadProfile();
        final original = await repository.getProfile();
        var notifications = 0;
        controller.addListener(() => notifications++);

        expect(() => controller.visibleItems.clear(), throwsUnsupportedError);
        expect((await repository.getProfile()).items, hasLength(5));
        expect(notifications, 0);

        controller.setCategoryFilter(FootprintCategory.dataBroker);
        expect(() => controller.visibleItems.clear(), throwsUnsupportedError);
        expect(controller.visibleItems, hasLength(1));
        expect(await repository.getProfile(), same(original));
        expect(notifications, 1);
      },
    );

    test('scanIdentity validates input and updates target profile', () async {
      final success = await controller.scanIdentity('nuevo_usuario@gmail.com');
      expect(success, isTrue);
      expect(controller.profile?.targetIdentity, 'nuevo_usuario@gmail.com');
      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
    });

    test('scanIdentity with empty string fails gracefully', () async {
      final success = await controller.scanIdentity('   ');
      expect(success, isFalse);
      expect(controller.error, isNotNull);
    });
  });
}
