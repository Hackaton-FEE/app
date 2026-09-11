import 'package:fee_app/features/footprint/data/flutter_secure_scan_storage.dart';
import 'package:fee_app/features/footprint/data/local_scan_history_repository.dart';
import 'package:fee_app/features/footprint/data/pending_scan_store.dart';
import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:fee_app/features/footprint/domain/scan_history_entry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native scan history persists, isolates accounts and preserves corruption',
    (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      final namespace = 'fee_scans_test_${const Uuid().v4()}';
      var now = DateTime.now().toUtc();
      FlutterSecureStorage native() => FlutterSecureStorage(
        aOptions: FlutterSecureScanStorage.androidOptions.copyWith(
          storageNamespace: namespace,
        ),
        iOptions: IOSOptions(
          accountName: namespace,
          accessibility: FlutterSecureScanStorage.iosOptions.accessibility,
          synchronizable: false,
        ),
      );
      LocalScanHistoryRepository repository(String prefix) =>
          LocalScanHistoryRepository(
            storage: FlutterSecureScanStorage(
              prefix: prefix,
              storage: native(),
            ),
            clock: () => now,
          );
      final entry = ScanHistoryEntry.fromProfile(
        id: 'scan',
        profile: FootprintProfile(
          targetIdentity: 'native-test@example.invalid',
          items: [],
          lastScannedAt: now,
        ),
      );
      try {
        PendingScanStore pending(String account) => PendingScanStore(
          FlutterSecureScanStorage(
            prefix: 'pending.$account.',
            storage: native(),
          ),
        );
        await pending('a')
            .save(const PendingScan('pending-scan', 'example_alias'));
        expect((await pending('a').load())!.id, 'pending-scan');
        expect(await pending('b').load(), isNull);
        await pending('a').clear();
        expect(await pending('a').load(), isNull);
        await repository('account-a.').saveScan(entry);
        await repository('account-b.').saveScan(entry);
        expect(
          (await repository('account-a.').loadHistory()).single.id,
          'scan',
        );
        await native().write(key: 'account-a.broken', value: '{broken');
        await expectLater(
          repository('account-a.').loadHistory(),
          throwsFormatException,
        );
        expect(await native().read(key: 'account-a.broken'), '{broken');
        await native().delete(key: 'account-a.broken');
        now = now.add(const Duration(days: 4));
        expect(await repository('account-a.').loadHistory(), isEmpty);
        expect(await native().read(key: 'account-b.scan'), isNotNull);
      } finally {
        await native().deleteAll();
      }
    },
  );
}
