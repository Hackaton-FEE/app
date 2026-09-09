import 'package:fee_app/features/cases/data/flutter_secure_case_storage.dart';
import 'package:fee_app/features/cases/data/local_case_repository.dart';
import 'package:fee_app/features/cases/domain/case_input.dart';
import 'package:fee_app/features/cases/domain/privacy_case.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native storage preserves the local case lifecycle', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());

    // Isolate both native storage artifacts and record keys from real app data.
    // Reopening the repository below does not restart the application process.
    final runId = const Uuid().v4();
    final namespace = 'fee_cases_integration_$runId';
    final prefix = 'integration.case.$runId.';
    final sentinelKey = 'integration.sentinel.$runId';
    const sentinelValue = 'unrelated test record';

    FlutterSecureStorage openNativeStorage() => FlutterSecureStorage(
      aOptions: FlutterSecureCaseStorage.androidOptions.copyWith(
        storageNamespace: namespace,
      ),
      iOptions: IOSOptions(
        accountName: namespace,
        accessibility: FlutterSecureCaseStorage.iosOptions.accessibility,
        synchronizable: FlutterSecureCaseStorage.iosOptions.synchronizable,
      ),
    );

    LocalCaseRepository openRepository() => LocalCaseRepository(
      storage: FlutterSecureCaseStorage(
        prefix: prefix,
        storage: openNativeStorage(),
      ),
    );

    final nativeStorage = openNativeStorage();
    try {
      await nativeStorage.write(key: sentinelKey, value: sentinelValue);
      final repository = openRepository();
      expect(await repository.loadCases(), isEmpty);

      final created = await repository.createCase(
        CaseInput(
          title: 'Ejemplo de integración',
          sourceUrl: 'https://example.com/first',
          category: CaseCategory.personalData,
          notes: 'Información ficticia para la prueba.',
        ),
      );
      final other = await repository.createCase(
        CaseInput(
          title: 'Segundo ejemplo',
          sourceUrl: 'https://example.com/second',
          category: CaseCategory.other,
        ),
      );

      final reopened = await openRepository().loadCases();
      expect(reopened, hasLength(2));
      final persisted = reopened.singleWhere((value) => value.id == created.id);
      expect(persisted.title, created.title);
      expect(persisted.sourceUrl, created.sourceUrl);
      expect(persisted.category, CaseCategory.personalData);
      expect(persisted.notes, created.notes);
      expect(persisted.status, CaseStatus.draft);
      expect(persisted.createdAt, created.createdAt);

      await openRepository().updateCase(
        created.id,
        CaseInput(
          title: 'Ejemplo editado',
          sourceUrl: 'https://example.com/updated?id=1',
          category: CaseCategory.impersonation,
          notes: 'Notas editadas: áéíóú.',
        ),
      );
      final edited = (await openRepository().loadCases()).singleWhere(
        (value) => value.id == created.id,
      );
      expect(edited.title, 'Ejemplo editado');
      expect(edited.sourceUrl.toString(), 'https://example.com/updated?id=1');
      expect(edited.category, CaseCategory.impersonation);
      expect(edited.notes, 'Notas editadas: áéíóú.');
      expect(edited.createdAt, created.createdAt);
      expect(edited.updatedAt.isBefore(created.createdAt), isFalse);

      await openRepository().setArchived(created.id, true);
      final archived = (await openRepository().loadCases()).singleWhere(
        (value) => value.id == created.id,
      );
      expect(archived.status, CaseStatus.archived);
      expect(archived.title, edited.title);

      await openRepository().setArchived(created.id, false);
      final restored = (await openRepository().loadCases()).singleWhere(
        (value) => value.id == created.id,
      );
      expect(restored.status, CaseStatus.draft);
      expect(restored.notes, edited.notes);

      await openRepository().deleteCase(created.id);
      final remaining = await openRepository().loadCases();
      expect(remaining.single.id, other.id);
      expect(await nativeStorage.read(key: '$prefix${created.id}'), isNull);
      expect(await nativeStorage.read(key: sentinelKey), sentinelValue);

      await openRepository().deleteCase(other.id);
      expect(await openRepository().loadCases(), isEmpty);
      expect(await nativeStorage.read(key: sentinelKey), sentinelValue);
    } finally {
      // No deleteAll: clean only this run's keys, even after an assertion fails.
      final keys = (await nativeStorage.readAll()).keys.where(
        (key) => key.startsWith(prefix) || key == sentinelKey,
      );
      for (final key in keys) {
        await nativeStorage.delete(key: key);
      }
    }
  });
}
