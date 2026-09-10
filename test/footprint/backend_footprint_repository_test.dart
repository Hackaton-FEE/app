import 'dart:convert';
import 'package:fee_app/features/footprint/data/backend_footprint_repository.dart';
import 'package:fee_app/features/footprint/data/osint_client.dart';
import 'package:fee_app/features/footprint/domain/footprint_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BackendFootprintRepository', () {
    test('scanIdentity initiates scan, polls and maps findings into FootprintProfile', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/osint/scans') {
          return http.Response(
            jsonEncode({'scan_id': 'test-scan-id', 'status': 'QUEUED'}),
            202,
          );
        }
        if (request.method == 'GET' && request.url.path == '/api/v1/osint/scans/test-scan-id') {
          return http.Response(
            jsonEncode({
              'scan_id': 'test-scan-id',
              'status': 'COMPLETED',
              'progress_percentage': 100,
              'completed_engines': ['blackbird', 'maigret'],
              'running_engines': <String>[],
              'partial_findings_count': 1,
            }),
            200,
          );
        }
        if (request.method == 'GET' && request.url.path == '/api/v1/osint/scans/test-scan-id/results') {
          return http.Response(
            jsonEncode({
              'scan_id': 'test-scan-id',
              'exposure_score': 75,
              'risk_level': 'ELEVATED',
              'categories': [
                {
                  'name': 'social',
                  'items_count': 1,
                  'items': [
                    {
                      'platform': 'Instagram',
                      'username': 'pedro.test',
                      'url': 'https://instagram.com/pedro.test',
                      'status': 'CONFIRMED',
                      'confidence': 90,
                      'sources': ['maigret'],
                      'details': {'full_name': 'Pedro Test', 'followers': 120},
                    }
                  ]
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final stages = <String>[];
      final osintClient = OsintClient(
        baseUrl: 'https://example.com/api/v1',
        accessToken: 'valid-jwt',
        httpClient: mockClient,
      );

      final repo = BackendFootprintRepository(
        client: osintClient,
        onProgressUpdate: (stage, pct) => stages.add(stage),
      );

      final profile = await repo.scanIdentity('pedro.test');

      expect(profile.targetIdentity, 'pedro.test');
      expect(profile.items, hasLength(1));
      expect(profile.items.first.platform, 'Instagram');
      expect(profile.items.first.category, FootprintCategory.socialProfile);
      expect(profile.items.first.riskLevel, FootprintRisk.high);
      expect(profile.items.first.title, contains('Pedro Test'));
      expect(stages, isNotEmpty);
    });
  });
}
