import 'dart:async';
import 'dart:convert';

import 'package:fee_app/features/footprint/data/backend_footprint_repository.dart';
import 'package:fee_app/features/footprint/data/osint_client.dart';
import 'package:fee_app/features/footprint/data/pending_scan_store.dart';
import 'package:fee_app/features/footprint/presentation/footprint_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'backend_footprint_repository_test.dart' show dashboardFixture;
import 'fake_scan_history_storage.dart';

void main() {
  test(
    'lost connection then recreation resumes the same ID without POST',
    () async {
      final storage = FakeScanHistoryStorage();
      var posts = 0;
      var offline = true;
      final paths = <String>[];
      BackendFootprintRepository create() => BackendFootprintRepository(
        pendingStore: PendingScanStore(storage),
        client: OsintClient(
          httpClient: MockClient((r) async {
            paths.add(r.url.path);
            if (r.method == 'POST') {
              posts++;
              return http.Response('{"scan_id":"test-scan-id"}', 202);
            }
            if (offline) throw http.ClientException('offline');
            if (r.url.path.endsWith('/results')) {
              return http.Response(jsonEncode(dashboardFixture()), 200);
            }
            return http.Response(
              '{"scan_id":"test-scan-id","status":"COMPLETED"}',
              200,
            );
          }),
        ),
      );
      await expectLater(
        create().scanIdentity('example_alias'),
        throwsA(isA<http.ClientException>()),
      );
      expect(await PendingScanStore(storage).load(), isNotNull);
      offline = false;
      final reopened = create();
      var saves = 0;
      final controller = FootprintController(
        reopened,
        onScanCompleted: (_) async => saves++,
      );
      await controller.loadProfile();
      expect(controller.profile!.targetIdentity, 'example_alias');
      expect(controller.profile!.osintReport!.scanId, 'test-scan-id');
      expect(posts, 1);
      expect(paths.last, endsWith('/test-scan-id/results'));
      expect(saves, 1);
      expect(await PendingScanStore(storage).load(), isNull);
      controller.dispose();
    },
  );

  test(
    'background interrupts a stale GET; foreground reads current result',
    () async {
      final oldRequest = Completer<http.Response>();
      final started = Completer<void>();
      var gets = 0;
      final client = OsintClient(
        httpClient: MockClient((_) {
          gets++;
          if (gets == 1) {
            started.complete();
            return oldRequest.future;
          }
          return Future.value(
            http.Response(
              '{"scan_id":"test-scan-id","status":"COMPLETED"}',
              200,
            ),
          );
        }),
      );
      final result = client.pollProgress('test-scan-id').toList();
      await started.future;
      client.activity.setForeground(false);
      await Future<void>.delayed(Duration.zero);
      expect(gets, 1);
      client.activity.setForeground(true);
      expect((await result).single.status, 'COMPLETED');
      oldRequest.completeError(
        http.ClientException('connection lost in background'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(gets, 2);
    },
  );

  test(
    'corrupt pending data is preserved and never starts another scan',
    () async {
      final storage = FakeScanHistoryStorage({'active': '{invalid'});
      var calls = 0;
      final repo = BackendFootprintRepository(
        pendingStore: PendingScanStore(storage),
        client: OsintClient(
          httpClient: MockClient((_) async {
            calls++;
            return http.Response('', 500);
          }),
        ),
      );
      await expectLater(
        repo.scanIdentity('example_alias'),
        throwsFormatException,
      );
      expect(calls, 0);
      expect((await storage.readAll())['active'], '{invalid');
    },
  );

  test('history failure keeps pending marker and previous profile', () async {
    final storage = FakeScanHistoryStorage();
    await PendingScanStore(storage)
        .save(const PendingScan('test-scan-id', 'example_alias'));
    final repo = BackendFootprintRepository(
      pendingStore: PendingScanStore(storage),
      client: OsintClient(
        httpClient: MockClient(
          (r) async => http.Response(
            r.url.path.endsWith('/results')
                ? jsonEncode(dashboardFixture())
                : '{"scan_id":"test-scan-id","status":"COMPLETED"}',
            200,
          ),
        ),
      ),
    );
    var fails = true;
    final controller = FootprintController(
      repo,
      onScanCompleted: (_) async {
        if (fails) throw StateError('storage unavailable');
      },
    );
    await controller.loadProfile();
    expect(controller.error, isNotNull);
    expect(controller.profile!.hasScanned, isFalse);
    expect(await PendingScanStore(storage).load(), isNotNull);
    fails = false;
    await controller.resumePendingScan();
    expect(controller.error, isNull);
    expect(controller.profile!.hasScanned, isTrue);
    expect(await PendingScanStore(storage).load(), isNull);
    controller.dispose();
  });

  test('wrong result ID preserves pending marker', () async {
    final storage = FakeScanHistoryStorage();
    await PendingScanStore(storage)
        .save(const PendingScan('test-scan-id', 'example_alias'));
    final fixture = dashboardFixture()..['scan_id'] = 'another-scan';
    final repo = BackendFootprintRepository(
      pendingStore: PendingScanStore(storage),
      client: OsintClient(
        httpClient: MockClient(
          (r) async => http.Response(
            r.url.path.endsWith('/results')
                ? jsonEncode(fixture)
                : '{"scan_id":"test-scan-id","status":"COMPLETED"}',
            200,
          ),
        ),
      ),
    );
    await expectLater(repo.resumePendingScan(), throwsFormatException);
    expect((await PendingScanStore(storage).load())!.id, 'test-scan-id');
  });

  test(
    'failed marker write retries persistence without another POST',
    () async {
      final storage = FakeScanHistoryStorage();
      var posts = 0;
      final repo = BackendFootprintRepository(
        pendingStore: PendingScanStore(storage),
        client: OsintClient(
          httpClient: MockClient((r) async {
            if (r.method == 'POST') {
              posts++;
              storage.shouldFail = true;
              return http.Response('{"scan_id":"test-scan-id"}', 202);
            }
            return http.Response(
              r.url.path.endsWith('/results')
                  ? jsonEncode(dashboardFixture())
                  : '{"scan_id":"test-scan-id","status":"COMPLETED"}',
              200,
            );
          }),
        ),
      );
      await expectLater(repo.scanIdentity('example_alias'), throwsStateError);
      storage.shouldFail = false;
      await repo.resumePendingScan();
      expect(posts, 1);
      expect((await PendingScanStore(storage).load())!.id, 'test-scan-id');
    },
  );

  test('failed remote scan clears pending but never reports success', () async {
    final storage = FakeScanHistoryStorage();
    await PendingScanStore(storage)
        .save(const PendingScan('test-scan-id', 'example_alias'));
    final repo = BackendFootprintRepository(
      pendingStore: PendingScanStore(storage),
      client: OsintClient(
        httpClient: MockClient(
          (_) async => http.Response(
            '{"scan_id":"test-scan-id","status":"FAILED"}',
            200,
          ),
        ),
      ),
    );
    await expectLater(repo.resumePendingScan(), throwsFormatException);
    expect(await PendingScanStore(storage).load(), isNull);
    expect((await repo.getProfile()).hasScanned, isFalse);
  });
}
