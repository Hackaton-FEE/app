import 'dart:convert';
import 'dart:io';

import 'package:fee_app/features/footprint/data/backend_footprint_repository.dart';
import 'package:fee_app/features/footprint/data/local_scan_history_repository.dart';
import 'package:fee_app/features/footprint/data/osint_client.dart';
import 'package:fee_app/features/footprint/domain/footprint_item.dart';
import 'package:fee_app/features/footprint/domain/scan_history_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_scan_history_storage.dart';

Map<String, dynamic> dashboardFixture() => jsonDecode(
  File('test/footprint/fixtures/correlated_dashboard.json').readAsStringSync(),
) as Map<String, dynamic>;

OsintClient fixtureClient(Map<String, dynamic> result) => OsintClient(
  baseUrl: 'https://example.com/api/v1',
  accessToken: 'test-token',
  httpClient: MockClient((request) async {
    if (request.method == 'POST') {
      return http.Response('{"scan_id":"test-scan-id"}', 202);
    }
    if (request.url.path.endsWith('/results')) {
      return http.Response.bytes(utf8.encode(jsonEncode(result)), 200);
    }
    return http.Response(
      '{"scan_id":"test-scan-id","status":"COMPLETED","progress_percentage":100}',
      200,
    );
  }),
);

void main() {
  test('maps backend score and correlations and preserves them after reopening history', () async {
    final stages = <int>[];
    final repository = BackendFootprintRepository(
      client: fixtureClient(dashboardFixture()),
      onProgressUpdate: (_, percentage) => stages.add(percentage),
    );
    final profile = await repository.scanIdentity('persona_demo');
    expect(profile.exposureScore, 75);
    expect(profile.overallRisk, FootprintRisk.high);
    expect(profile.items.single.title, contains('Persona de prueba'));
    expect(profile.osintReport!.partial, isTrue);
    expect(profile.osintReport!.correlation!.edges.single.target, 'n2');
    expect(stages.last, 100);

    final storage = FakeScanHistoryStorage();
    DateTime clock() => DateTime.utc(2026, 9, 10, 13);
    await LocalScanHistoryRepository(storage: storage, clock: clock).saveScan(
      ScanHistoryEntry.fromProfile(id: 'saved-scan', profile: profile),
    );
    final reopened = LocalScanHistoryRepository(storage: storage, clock: clock);
    final restored = (await reopened.loadHistory()).single.toProfile();
    expect(restored.exposureScore, 75);
    expect(restored.osintReport!.rateLimited, 1);
    expect(
      restored.osintReport!.correlation!.contacts.single.pattern,
      'p***@example.com',
    );
    expect(restored.osintReport!.correlation!.timeline.oldAccounts, [
      'Example Social',
    ]);
  });

  test(
    'scan error propagates without a success event or invented findings',
    () async {
      final stages = <int>[];
      final repository = BackendFootprintRepository(
        targetIdentity: 'persona_demo',
        client: OsintClient(
          httpClient: MockClient((_) async => http.Response('private', 429)),
        ),
        onProgressUpdate: (_, percentage) => stages.add(percentage),
      );
      await expectLater(
        repository.scanIdentity('persona_demo'),
        throwsFormatException,
      );
      expect(stages, isNot(contains(100)));
      expect((await repository.getProfile()).items, isEmpty);
      expect((await repository.getProfile()).hasScanned, isFalse);
    },
  );

  test(
    'malformed correlation does not replace a previously confirmed profile',
    () async {
      final result = dashboardFixture();
      final repository = BackendFootprintRepository(
        client: fixtureClient(result),
      );
      final previous = await repository.scanIdentity('persona_demo');
      result['correlation']['identity_graph']['edges'][0]['target'] = 'missing';
      await expectLater(
        repository.scanIdentity('different_alias'),
        throwsFormatException,
      );
      expect(await repository.getProfile(), same(previous));
    },
  );

  test('older backend without correlation remains readable', () async {
    final result = dashboardFixture()..remove('correlation');
    final profile = await BackendFootprintRepository(
      client: fixtureClient(result),
    ).scanIdentity('persona_demo');
    expect(profile.osintReport!.correlation, isNull);
    expect(profile.exposureScore, 75);
  });

  test(
    'missing or invalid finding fields cannot replace confirmed results',
    () async {
      final invalidChanges = <String, void Function(Map<String, dynamic>)>{
        for (final field in [
          'platform',
          'username',
          'url',
          'status',
          'confidence',
          'sources',
          'details',
        ])
          'missing $field': (finding) => finding.remove(field),
        'unknown status': (finding) => finding['status'] = 'NOT_FOUND',
        'null status': (finding) => finding['status'] = null,
        'empty platform': (finding) => finding['platform'] = ' ',
        'non-string username': (finding) => finding['username'] = 123,
        'non-string url': (finding) => finding['url'] = [],
        'negative confidence': (finding) => finding['confidence'] = -1,
        'excess confidence': (finding) => finding['confidence'] = 101,
        'fractional confidence': (finding) => finding['confidence'] = 85.5,
        'null confidence': (finding) => finding['confidence'] = null,
        'non-string source': (finding) => finding['sources'] = [123],
        'null sources': (finding) => finding['sources'] = null,
        'null details': (finding) => finding['details'] = null,
        'array details': (finding) => finding['details'] = [],
      };
      final result = dashboardFixture();
      final stages = <int>[];
      final repository = BackendFootprintRepository(
        client: fixtureClient(result),
        onProgressUpdate: (_, percentage) => stages.add(percentage),
      );
      final previous = await repository.scanIdentity('persona_demo');
      for (final change in invalidChanges.entries) {
        result
          ..clear()
          ..addAll(dashboardFixture());
        change.value(
          result['categories'][0]['items'][0] as Map<String, dynamic>,
        );
        stages.clear();
        await expectLater(
          repository.scanIdentity('different_alias'),
          throwsFormatException,
          reason: change.key,
        );
        expect(
          await repository.getProfile(),
          same(previous),
          reason: change.key,
        );
        expect(stages, isNot(contains(100)), reason: change.key);
      }
    },
  );

  test('invalid categories or timestamps preserve the prior result and expose an error', () async {
    final mutations = <String, void Function(Map<String, dynamic>)>{
      'missing categories': (result) => result.remove('categories'),
      'null categories': (result) => result['categories'] = null,
      'invalid category': (result) => result['categories'] = ['not an object'],
      for (final field in ['name', 'color_hex', 'items_count', 'items'])
        'missing category $field': (result) =>
            result['categories'][0].remove(field),
      'null category name': (result) => result['categories'][0]['name'] = null,
      'invalid category color': (result) =>
          result['categories'][0]['color_hex'] = 'red',
      'null category items': (result) =>
          result['categories'][0]['items'] = null,
      'mismatched category count': (result) =>
          result['categories'][0]['items_count'] = 2,
      'invalid category count': (result) =>
          result['categories'][0]['items_count'] = -1,
      'null timestamp': (result) => result['generated_at'] = null,
      'impossible date': (result) =>
          result['generated_at'] = '2026-02-30T12:00:00Z',
      'impossible hour': (result) =>
          result['generated_at'] = '2026-09-10T25:00:00Z',
      'empty scan ID': (result) => result['scan_id'] = ' ',
    };
    final result = dashboardFixture();
    final repository = BackendFootprintRepository(
      client: fixtureClient(result),
    );
    final previous = await repository.scanIdentity('persona_demo');
    for (final mutation in mutations.entries) {
      result
        ..clear()
        ..addAll(dashboardFixture());
      mutation.value(result);
      await expectLater(
        repository.scanIdentity('different_alias'),
        throwsFormatException,
        reason: mutation.key,
      );
      expect(
        await repository.getProfile(),
        same(previous),
        reason: mutation.key,
      );
    }
  });

  test(
    'blocked checks are validated before they are excluded from findings',
    () async {
      final result = dashboardFixture();
      final finding =
          result['categories'][0]['items'][0] as Map<String, dynamic>;
      finding['status'] = 'RATE_LIMITED';
      finding.remove('confidence');
      final repository = BackendFootprintRepository(
        client: fixtureClient(result),
      );
      await expectLater(
        repository.scanIdentity('persona_demo'),
        throwsFormatException,
      );
      expect((await repository.getProfile()).hasScanned, isFalse);
    },
  );

  test('nullable identity and URL plus confidence boundaries keep their real values', () async {
    for (final confidence in [0, 100]) {
      final result = dashboardFixture();
      final finding =
          result['categories'][0]['items'][0] as Map<String, dynamic>;
      finding['username'] = null;
      finding['url'] = null;
      finding['confidence'] = confidence;
      finding['details'] = <String, dynamic>{};
      final profile = await BackendFootprintRepository(
        client: fixtureClient(result),
      ).scanIdentity('persona_demo');
      expect(profile.items.single.confidence, confidence);
      expect(profile.items.single.sourceUrl, isEmpty);
      expect(
        profile.items.single.exposedData.where(
          (text) => text.startsWith('Usuario:'),
        ),
        isEmpty,
      );
    }
  });

  test('a completed empty result contains no invented findings', () async {
    final result = dashboardFixture()..['categories'] = <dynamic>[];
    final profile = await BackendFootprintRepository(
      client: fixtureClient(result),
    ).scanIdentity('persona_demo');
    expect(profile.items, isEmpty);
    expect(profile.hasScanned, isTrue);
  });

  test('an account without an identifier or saved report has an empty initial state', () async {
    final repository = BackendFootprintRepository(
      client: fixtureClient(dashboardFixture()),
      targetIdentity: '',
      historyRepository: LocalScanHistoryRepository(
        storage: FakeScanHistoryStorage(),
      ),
    );
    final profile = await repository.getProfile();
    expect(profile.targetIdentity, isEmpty);
    expect(profile.items, isEmpty);
    expect(profile.osintReport, isNull);
    expect(profile.hasScanned, isFalse);
  });
}
