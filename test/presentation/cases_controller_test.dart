import 'dart:async';

import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:fee_app/features/cases/domain/case_input.dart';
import 'package:fee_app/features/cases/domain/privacy_case.dart';
import 'package:fee_app/features/cases/presentation/cases_controller.dart';
import 'package:fee_app/features/cases/presentation/cases_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_case_storage.dart';

void main() {
  late FakeCaseStorage storage;
  late CasesController controller;

  CaseInput input({String title = 'Caso de prueba'}) => CaseInput(
    title: title,
    sourceUrl: 'https://example.com/reference',
    category: CaseCategory.personalData,
  );

  setUp(() {
    storage = FakeCaseStorage();
    controller = CasesController(LocalCaseRepository(storage: storage));
  });
  tearDown(() => controller.dispose());

  test(
    'publishes only after persistence and prevents duplicate submissions',
    () async {
      await controller.load();
      storage.writeGate = Completer<void>();
      storage.writeStarted = Completer<void>();
      final saving = controller.saveCase(input());
      await storage.writeStarted!.future;
      expect(controller.state.isSaving, isTrue);
      expect(controller.state.cases, isEmpty);
      expect(await controller.saveCase(input()), isNull);
      expect(storage.writes, 1);
      storage.writeGate!.complete();
      expect(await saving, isNotNull);
      expect(controller.state.isSaving, isFalse);
      expect(controller.state.cases, hasLength(1));
      expect(() => controller.state.cases.clear(), throwsUnsupportedError);
    },
  );

  test('failed load prevents writes and retry recovers', () async {
    storage.failRead = true;
    await controller.load();
    expect(controller.state.isLoading, isFalse);
    expect(controller.state.loadError, isNotNull);
    expect(
      controller.state.loadError,
      isNot(contains('private-storage-detail')),
    );
    expect(await controller.saveCase(input()), isNull);
    expect(storage.writes, 0);
    storage.failRead = false;
    await controller.load();
    expect(controller.state.loadError, isNull);
    expect(await controller.saveCase(input()), isNotNull);
  });

  test('failed save or delete keeps existing state and allows retry', () async {
    await controller.load();
    final first = (await controller.saveCase(input()))!;
    storage.failWrite = true;
    expect(
      await controller.saveCase(input(title: 'Editado'), id: first.id),
      isNull,
    );
    expect(controller.findCase(first.id)!.title, first.title);
    expect(controller.state.actionError, isNotNull);
    storage.failWrite = false;
    expect(
      await controller.saveCase(input(title: 'Editado'), id: first.id),
      isNotNull,
    );
    expect(controller.state.actionError, isNull);
    storage.failDelete = true;
    expect(await controller.deleteCase(first.id), isFalse);
    expect(controller.findCase(first.id), isNotNull);
    storage.failDelete = false;
    expect(await controller.deleteCase(first.id), isTrue);
    expect(controller.findCase(first.id), isNull);
  });

  test('search and archive filters follow persisted state', () async {
    await controller.load();
    final first = (await controller.saveCase(input(title: 'Primer caso')))!;
    await controller.saveCase(input(title: 'Segundo caso'));
    controller.search(' PRIMER ');
    expect(controller.visibleCases.single.id, first.id);
    await controller.setArchived(first.id, true);
    expect(controller.visibleCases, isEmpty);
    expect(controller.activeCount, 1);
    expect(controller.archivedCount, 1);
    controller.setFilter(CaseFilter.archived);
    expect(controller.visibleCases.single.id, first.id);
    controller.search('example.com');
    expect(controller.visibleCases, hasLength(1));
    await controller.setArchived(first.id, false);
    expect(controller.visibleCases, isEmpty);
    expect(controller.activeCount, 2);
  });

  test('corrupt data is not treated as an empty successful load', () async {
    storage.records['broken'] = '{invalid';
    await controller.load();
    expect(controller.state.loadError, contains('Conservamos los datos'));
    expect(await controller.saveCase(input()), isNull);
    expect(storage.records['broken'], '{invalid');
  });

  test('an async completion never notifies a disposed view model', () async {
    final other = CasesController(LocalCaseRepository(storage: storage));
    await other.load();
    storage.writeGate = Completer<void>();
    storage.writeStarted = Completer<void>();
    final saving = other.saveCase(input());
    await storage.writeStarted!.future;
    other.dispose();
    storage.writeGate!.complete();
    expect(await saving, isNull);
    expect(storage.records, hasLength(1));
  });
}
