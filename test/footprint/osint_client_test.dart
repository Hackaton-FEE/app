import 'dart:convert';
import 'package:fee_app/features/footprint/data/osint_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OsintClient', () {
    test('startScan sends target_type username and returns scan_id on 202', () async {
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
    });

    test('startScan detects email target_type for email identifier', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['target_type'], 'email');
        expect(body['identifier'], 'test@example.com');
        expect(body['associated_email'], 'test@example.com');

        return http.Response(
          jsonEncode({'scan_id': 'scan-email'}),
          202,
        );
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
                  }
                ]
              }
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
  });
}
