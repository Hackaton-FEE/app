import 'dart:async';
import 'dart:convert';

import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:fee_app/features/cases/domain/case_input.dart';
import 'package:fee_app/features/cases/domain/case_repository.dart';
import 'package:fee_app/features/cases/domain/privacy_case.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_case_storage.dart';

void main() {
  const firstId = '10000000-0000-4000-8000-000000000001';
  const secondId = '10000000-0000-4000-8000-000000000002';
  final firstTime = DateTime.utc(2026, 9, 9, 12);
  late DateTime now;
  late FakeCaseStorage storage;
  late LocalCaseRepository repository;
  late int nextId;

  CaseInput input({String title = 'Caso de prueba', String notes = ''}) =>
      CaseInput(
        title: title,
        sourceUrl: 'https://example.com/item',
        category: CaseCategory.personalData,
        notes: notes,
      );

  Matcher failure(CaseRepositoryExceptionReason reason) => throwsA(
    isA<CaseRepositoryException>()
        .having((error) => error.reason, 'reason', reason)
        .having(
          (error) => error.toString(),
          'redacted error',
          isNot(contains('private-storage-detail')),
        ),
  );

  test('large Unicode metadata remains readable after persistence', () async {
    const sourcePrefix = 'https://example.com/';
    final source =
        sourcePrefix +
        ('a' * (CaseInput.maxSourceLinkLength - sourcePrefix.length));
    final largeInput = CaseInput(
      title: '👩🏽‍💻' * 80,
      sourceUrl: source,
      category: CaseCategory.personalData,
      notes: 'a${'\u0301' * 10000}',
    );
    final created = await repository.createCase(largeInput);
    final recordBytes = utf8.encode(storage.records[firstId]!).length;
    expect(recordBytes, greaterThan(22000));
    expect(recordBytes, lessThanOrEqualTo(32 * 1024));
    final loaded = (await LocalCaseRepository(
      storage: storage,
    ).loadCases()).single;
    expect(loaded.title, created.title);
    expect(loaded.notes, created.notes);
    expect(loaded.sourceUrl, created.sourceUrl);
  });

  test(
    'JSON escaping cannot create an unreadable record at field limits',
    () async {
      final escapedInput = CaseInput(
        title: '\u0001' * 80,
        sourceUrl: 'https://example.com/',
        category: CaseCategory.other,
        notes: '\u0001' * 2000,
      );
      final created = await repository.createCase(escapedInput);
      final loaded = (await LocalCaseRepository(
        storage: storage,
      ).loadCases()).single;
      expect(loaded.title, created.title);
      expect(loaded.notes, created.notes);
    },
  );

  setUp(() {
    now = firstTime;
    nextId = 0;
    storage = FakeCaseStorage();
    repository = LocalCaseRepository(
      storage: storage,
      clock: () => now,
      idFactory: () => [firstId, secondId][nextId++],
    );
  });

  test(
    'creation persists one versioned record and survives a new repository',
    () async {
      final created = await repository.createCase(input(notes: 'Nota local'));
      expect(created.id, firstId);
      expect(created.status, CaseStatus.draft);
      expect(created.createdAt, firstTime);
      expect(created.updatedAt, firstTime);
      expect(storage.records.keys, [firstId]);
      final record =
          jsonDecode(storage.records[firstId]!) as Map<String, dynamic>;
      expect(record['schemaVersion'], 1);
      expect(record['id'], firstId);

      final restarted = LocalCaseRepository(storage: storage);
      final loaded = (await restarted.loadCases()).single;
      expect(loaded.id, created.id);
      expect(loaded.title, created.title);
      expect(loaded.notes, 'Nota local');
      expect(loaded.sourceUrl, created.sourceUrl);
      expect(loaded.category, created.category);
      expect(loaded.status, created.status);
      expect(loaded.createdAt, created.createdAt);
      expect(loaded.updatedAt, created.updatedAt);
    },
  );

  test(
    'editing preserves identity, creation time, and archived state',
    () async {
      await repository.createCase(input());
      await repository.setArchived(firstId, true);
      now = firstTime.add(const Duration(hours: 2));
      final edited = await repository.updateCase(
        firstId,
        CaseInput(
          title: 'Título editado',
          sourceUrl: 'https://example.com/updated',
          category: CaseCategory.impersonation,
          notes: 'Información nueva',
        ),
      );
      expect(edited.id, firstId);
      expect(edited.createdAt, firstTime);
      expect(edited.updatedAt, now);
      expect(edited.status, CaseStatus.archived);
      final restored = (await LocalCaseRepository(
        storage: storage,
      ).loadCases()).single;
      expect(restored.title, 'Título editado');
      expect(restored.sourceUrl.path, '/updated');
      expect(restored.category, CaseCategory.impersonation);
      expect(restored.notes, 'Información nueva');
    },
  );

  test(
    'archive and restore survive restarts; delete affects only its case',
    () async {
      await repository.createCase(input());
      await repository.createCase(input(title: 'Segundo'));
      final archived = await repository.setArchived(firstId, true);
      expect(archived.status, CaseStatus.archived);
      repository = LocalCaseRepository(storage: storage);
      final archivedAfterRestart = (await repository.loadCases()).firstWhere(
        (value) => value.id == firstId,
      );
      expect(archivedAfterRestart.status, CaseStatus.archived);
      expect(
        (await repository.setArchived(firstId, false)).status,
        CaseStatus.draft,
      );
      await repository.deleteCase(firstId);
      final loaded = await LocalCaseRepository(storage: storage).loadCases();
      expect(loaded.single.id, secondId);
      expect(storage.records.keys, [secondId]);
    },
  );

  test('reads are immutable and sorted by latest update', () async {
    await repository.createCase(input());
    now = firstTime.add(const Duration(minutes: 1));
    await repository.createCase(input(title: 'Segundo'));
    expect((await repository.loadCases()).map((value) => value.id), [
      secondId,
      firstId,
    ]);
    now = firstTime.add(const Duration(minutes: 2));
    await repository.updateCase(firstId, input(title: 'Editado'));
    final loaded = await repository.loadCases();
    expect(loaded.map((value) => value.id), [firstId, secondId]);
    expect(loaded.clear, throwsUnsupportedError);
  });

  test(
    'a device-clock rollback does not make persisted timestamps invalid',
    () async {
      await repository.createCase(input());
      now = firstTime.subtract(const Duration(days: 1));
      final edited = await repository.updateCase(
        firstId,
        input(title: 'Editado'),
      );
      expect(edited.updatedAt, firstTime);
      expect((await repository.loadCases()).single.id, firstId);
    },
  );

  for (final operation in ['update', 'archive', 'delete']) {
    test(
      '$operation reports missing records instead of inventing success',
      () async {
        final result = switch (operation) {
          'update' => repository.updateCase(firstId, input()),
          'archive' => repository.setArchived(firstId, true),
          _ => repository.deleteCase(firstId),
        };
        await expectLater(
          result,
          failure(CaseRepositoryExceptionReason.notFound),
        );
        expect(storage.writes, 0);
        expect(storage.deletes, 0);
      },
    );
  }

  for (final corruption in [
    'invalid-json',
    'future-version',
    'wrong-id',
    'unknown-category',
    'unknown-status',
    'invalid-date',
    'reversed-dates',
    'invalid-title',
    'invalid-url',
    'unknown-field',
    'non-canonical',
    'non-integer-version',
  ]) {
    test(
      '$corruption fails without discarding or overwriting original data',
      () async {
        await repository.createCase(input());
        final value =
            jsonDecode(storage.records[firstId]!) as Map<String, dynamic>;
        switch (corruption) {
          case 'future-version':
            value['schemaVersion'] = 2;
          case 'wrong-id':
            value['id'] = secondId;
          case 'unknown-category':
            value['category'] = 'futureCategory';
          case 'unknown-status':
            value['status'] = 'submitted';
          case 'invalid-date':
            value['createdAt'] = '2026-02-30T00:00:00.000Z';
          case 'reversed-dates':
            value['updatedAt'] = '2020-01-01T00:00:00.000Z';
          case 'invalid-title':
            value['title'] = '';
          case 'invalid-url':
            value['sourceUrl'] = 'file:///example';
          case 'unknown-field':
            value['futureData'] = 'preserve';
          case 'non-canonical':
            value['notes'] = ' trailing ';
          case 'non-integer-version':
            value['schemaVersion'] = 1.0;
        }
        storage.records[firstId] = corruption == 'invalid-json'
            ? '{invalid'
            : jsonEncode(value);
        final original = Map.of(storage.records);
        final writesBefore = storage.writes;
        await expectLater(
          repository.loadCases(),
          failure(CaseRepositoryExceptionReason.invalidStoredData),
        );
        await expectLater(
          repository.createCase(input()),
          failure(CaseRepositoryExceptionReason.invalidStoredData),
        );
        await expectLater(
          repository.updateCase(firstId, input()),
          failure(CaseRepositoryExceptionReason.invalidStoredData),
        );
        await expectLater(
          repository.deleteCase(firstId),
          failure(CaseRepositoryExceptionReason.invalidStoredData),
        );
        expect(storage.records, original);
        expect(storage.writes, writesBefore);
        expect(storage.deletes, 0);
      },
    );
  }

  test('read failure is typed and a later read can recover', () async {
    await repository.createCase(input());
    storage.failRead = true;
    await expectLater(
      repository.loadCases(),
      failure(CaseRepositoryExceptionReason.storageUnavailable),
    );
    storage.failRead = false;
    expect((await repository.loadCases()).single.id, firstId);
  });

  test(
    'failed writes do not publish creates or change existing records',
    () async {
      storage.failWrite = true;
      await expectLater(
        repository.createCase(input()),
        failure(CaseRepositoryExceptionReason.storageUnavailable),
      );
      expect(await repository.loadCases(), isEmpty);
      storage.failWrite = false;
      final created = await repository.createCase(input());
      final original = Map.of(storage.records);
      storage.failWrite = true;
      await expectLater(
        repository.updateCase(created.id, input(title: 'No guardado')),
        failure(CaseRepositoryExceptionReason.storageUnavailable),
      );
      await expectLater(
        repository.setArchived(created.id, true),
        failure(CaseRepositoryExceptionReason.storageUnavailable),
      );
      expect(storage.records, original);
      final loaded = (await repository.loadCases()).single;
      expect(loaded.title, created.title);
      expect(loaded.status, CaseStatus.draft);
    },
  );

  test('failed deletion preserves data and can be retried', () async {
    await repository.createCase(input());
    storage.failDelete = true;
    await expectLater(
      repository.deleteCase(firstId),
      failure(CaseRepositoryExceptionReason.storageUnavailable),
    );
    expect((await repository.loadCases()).single.id, firstId);
    storage.failDelete = false;
    await repository.deleteCase(firstId);
    expect(await repository.loadCases(), isEmpty);
  });

  test('pending persistence blocks success and subsequent reads', () async {
    storage.writeGate = Completer<void>();
    storage.writeStarted = Completer<void>();
    var createComplete = false;
    var readComplete = false;
    final create = repository.createCase(input()).then((value) {
      createComplete = true;
      return value;
    });
    await storage.writeStarted!.future;
    final read = repository.loadCases().then((value) {
      readComplete = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(createComplete, isFalse);
    expect(readComplete, isFalse);
    expect(storage.records, isEmpty);
    storage.writeGate!.complete();
    expect((await create).id, firstId);
    expect((await read).single.id, firstId);
  });

  test(
    'concurrent mutations are serialized and preserve later updates',
    () async {
      final firstCreate = repository.createCase(input());
      final edit = repository.updateCase(firstId, input(title: 'Editado'));
      final archive = repository.setArchived(firstId, true);
      final secondCreate = repository.createCase(input(title: 'Segundo'));
      await Future.wait([firstCreate, edit, archive, secondCreate]);
      final loaded = await repository.loadCases();
      expect(loaded, hasLength(2));
      final first = loaded.firstWhere((value) => value.id == firstId);
      expect(first.title, 'Editado');
      expect(first.status, CaseStatus.archived);
      expect(storage.records, hasLength(2));
    },
  );

  test('an identifier collision never overwrites an existing record', () async {
    await repository.createCase(input());
    final colliding = LocalCaseRepository(
      storage: storage,
      idFactory: () => firstId,
    );
    await expectLater(
      colliding.createCase(input(title: 'Colisión')),
      failure(CaseRepositoryExceptionReason.storageUnavailable),
    );
    expect((await repository.loadCases()).single.title, 'Caso de prueba');
    expect(storage.writes, 1);
  });
}
