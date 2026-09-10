import 'dart:async';
import 'dart:convert';

import 'package:fee_app/features/footprint/data/osint_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OsintClient', () {
    test(
      'international phone uses phone target and normalized digits',
      () async {
        final client = OsintClient(
          httpClient: MockClient((request) async {
            final body = jsonDecode(request.body);
            expect(body['target_type'], 'phone');
            expect(body['identifier'], '+525500000000');
            expect(body['associated_email'], isNull);
            return http.Response('{"scan_id":"phone-test"}', 202);
          }),
        );
        expect(
          await client.startScan(mainIdentifier: '+52 (55) 0000-0000'),
          'phone-test',
        );
        await expectLater(
          client.startScan(mainIdentifier: '+not-a-phone'),
          throwsFormatException,
        );
      },
    );

    test('failed status throws and unfinished polling times out', () async {
      for (final status in ['FAILED', 'RUNNING']) {
        final client = OsintClient(
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({'scan_id': 'scan', 'status': status}),
              200,
            ),
          ),
        );
        await expectLater(
          client
              .pollProgress('scan', interval: Duration.zero, maxPolls: 1)
              .toList(),
          status == 'FAILED'
              ? throwsFormatException
              : throwsA(isA<TimeoutException>()),
        );
      }
    });

    test(
      'startScan sends target_type username and returns scan_id on 202',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/v1/osint/scans');
          expect(request.headers['Authorization'], 'Bearer test-jwt');
          expect(request.headers['User-Agent'], 'fee_app/0.1.0');

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['target_type'], 'username');
          expect(body['identifier'], 'pedroai');
          expect(body['consent_self_audit'], isTrue);

          return http.Response(
            jsonEncode({
              'scan_id': 'scan-12345',
              'status': 'QUEUED',
              'estimated_duration_seconds': 90,
              'polling_url': '/api/v1/osint/scans/scan-12345',
              'events_url': '/api/v1/osint/scans/scan-12345/events',
            }),
            202,
          );
        });

        final client = OsintClient(
          baseUrl: 'https://example.com/api/v1',
          accessToken: 'test-jwt',
          httpClient: mockClient,
        );

        final scanId = await client.startScan(mainIdentifier: 'pedroai');
        expect(scanId, 'scan-12345');
      },
    );

    test('startScan detects email target_type for email identifier', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['target_type'], 'email');
        expect(body['identifier'], 'test@example.com');
        expect(body['associated_email'], 'test@example.com');

        return http.Response(jsonEncode({'scan_id': 'scan-email'}), 202);
      });

      final client = OsintClient(
        baseUrl: 'https://example.com/api/v1',
        accessToken: 'test-jwt',
        httpClient: mockClient,
      );

      final scanId = await client.startScan(mainIdentifier: 'test@example.com');
      expect(scanId, 'scan-email');
    });

    test('pollProgress yields status and finishes on COMPLETED', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode({
              'scan_id': 'scan-1',
              'status': 'RUNNING',
              'progress_percentage': 35,
              'completed_engines': ['blackbird'],
              'running_engines': ['maigret', 'holehe'],
              'partial_findings_count': 5,
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'scan_id': 'scan-1',
            'status': 'COMPLETED',
            'progress_percentage': 100,
            'completed_engines': ['blackbird', 'maigret', 'holehe'],
            'running_engines': <String>[],
            'partial_findings_count': 142,
          }),
          200,
        );
      });

      final client = OsintClient(
        baseUrl: 'https://example.com/api/v1',
        accessToken: 'test-jwt',
        httpClient: mockClient,
      );

      final events = await client
          .pollProgress('scan-1', interval: const Duration(milliseconds: 10))
          .toList();

      expect(events, hasLength(2));
      expect(events[0].progressPercentage, 35);
      expect(events[0].status, 'RUNNING');
      expect(events[1].progressPercentage, 100);
      expect(events[1].status, 'COMPLETED');
    });

    test(
      'polling renews once and continues the same scan without another POST',
      () async {
        var token = 'expired-token';
        var refreshes = 0;
        final seenTokens = <String?>[];
        final client = OsintClient(
          baseUrl: 'https://example.com/api/v1',
          tokenProvider: () => token,
          asyncTokenProvider: ({forceRefresh = false}) async {
            expect(forceRefresh, isTrue);
            refreshes++;
            return token = 'fresh-token';
          },
          httpClient: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/api/v1/osint/scans/existing-scan');
            seenTokens.add(request.headers['Authorization']);
            if (seenTokens.length == 1) return http.Response('{}', 401);
            return http.Response(
              jsonEncode({
                'scan_id': 'existing-scan',
                'status': seenTokens.length == 2 ? 'RUNNING' : 'COMPLETED',
              }),
              200,
            );
          }),
        );

        final events = await client
            .pollProgress('existing-scan', interval: Duration.zero, maxPolls: 2)
            .toList();

        expect(events.map((event) => event.status), ['RUNNING', 'COMPLETED']);
        expect(refreshes, 1);
        expect(seenTokens, [
          'Bearer expired-token',
          'Bearer fresh-token',
          'Bearer fresh-token',
        ]);
      },
    );

    test('polling surfaces a repeated 401 without looping refresh', () async {
      var requests = 0;
      var refreshes = 0;
      final client = OsintClient(
        accessToken: 'expired-token',
        asyncTokenProvider: ({forceRefresh = false}) async {
          expect(forceRefresh, isTrue);
          refreshes++;
          return 'rejected-token';
        },
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/osint/scans/existing-scan');
          requests++;
          return http.Response('{}', 401);
        }),
      );

      await expectLater(
        client.pollProgress('existing-scan', interval: Duration.zero).toList(),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Sesión no autorizada'),
          ),
        ),
      );
      expect(requests, 2);
      expect(refreshes, 1);
    });

    test(
      'polling preserves a renewal error without reporting completion',
      () async {
        var requests = 0;
        final failure = StateError('Session renewal unavailable');
        final client = OsintClient(
          accessToken: 'expired-token',
          asyncTokenProvider: ({forceRefresh = false}) async => throw failure,
          httpClient: MockClient((_) async {
            requests++;
            return http.Response('{}', 401);
          }),
        );
        final events = <OsintProgress>[];

        await expectLater(
          client
              .pollProgress('existing-scan', interval: Duration.zero)
              .forEach(events.add),
          throwsA(same(failure)),
        );
        expect(events, isEmpty);
        expect(requests, 1);
      },
    );

    test('fetchResults retrieves consolidated findings', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/osint/scans/scan-1/results');
        return http.Response(
          jsonEncode({
            'scan_id': 'scan-1',
            'exposure_score': 68,
            'risk_level': 'MODERATE',
            'summary': {'platforms_found': 10},
            'categories': [
              {
                'name': 'coding',
                'items_count': 1,
                'items': [
                  {
                    'platform': 'GitHub',
                    'username': 'pedroai',
                    'url': 'https://github.com/pedroai',
                    'status': 'CONFIRMED',
                    'confidence': 95,
                    'sources': ['blackbird'],
                    'details': {'full_name': 'Pedro Ibarra'},
                  },
                ],
              },
            ],
          }),
          200,
        );
      });

      final client = OsintClient(
        baseUrl: 'https://example.com/api/v1',
        accessToken: 'test-jwt',
        httpClient: mockClient,
      );

      final results = await client.fetchResults('scan-1');
      expect(results['exposure_score'], 68);
      expect(results['risk_level'], 'MODERATE');
      expect((results['categories'] as List).length, 1);
    });

    test(
      'tokenProvider dynamically evaluates fresh token on each request',
      () async {
        String? dynamicToken = 'token-1';
        final seenTokens = <String?>[];

        final mockClient = MockClient((request) async {
          seenTokens.add(request.headers['Authorization']);
          return http.Response(jsonEncode({'scan_id': 's1'}), 202);
        });

        final client = OsintClient(
          baseUrl: 'https://example.com/api/v1',
          tokenProvider: () => dynamicToken,
          httpClient: mockClient,
        );

        await client.startScan(mainIdentifier: 'id1');
        dynamicToken = 'token-2';
        await client.startScan(mainIdentifier: 'id2');

        expect(seenTokens, ['Bearer token-1', 'Bearer token-2']);
      },
    );

    test('startScan parses 429 slowapi rate limit cleanly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Rate limit exceeded: 5 per 1 hour'}),
          429,
        );
      });

      final client = OsintClient(
        baseUrl: 'https://example.com/api/v1',
        accessToken: 'test-jwt',
        httpClient: mockClient,
      );

      expect(
        () => client.startScan(mainIdentifier: 'test-id'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Límite de escaneos alcanzado'),
          ),
        ),
      );
    });

    test('startScan parses 401 unauthorized cleanly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'Invalid Session'}), 401);
      });

      final client = OsintClient(
        baseUrl: 'https://example.com/api/v1',
        accessToken: 'test-jwt',
        httpClient: mockClient,
      );

      expect(
        () => client.startScan(mainIdentifier: 'test-id'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Sesión no autorizada'),
          ),
        ),
      );
    });
  });
}
