import 'dart:convert';
import 'dart:io';

import 'package:fee_app/features/footprint/data/backend_footprint_repository.dart';
import 'package:fee_app/features/footprint/data/osint_client.dart';
import 'package:fee_app/features/footprint/domain/scan_identifiers.dart';
import 'package:fee_app/features/footprint/presentation/footprint_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'all required engine inputs are normalized without inferred identifiers',
    () {
      final input = ScanIdentifiers(
        email: ' owner@example.com ',
        phone: '+1 (202) 555-0123',
        aliases: 'owner, owner, owner_dev',
      );
      expect(input.phone, '+12025550123');
      expect(input.email, 'owner@example.com');
      expect(input.aliases, ['owner', 'owner_dev']);
      expect(() => input.aliases.add('other'), throwsUnsupportedError);
      for (final values in [
        ('', '+12025550123', 'owner'),
        ('owner@example.com', '', 'owner'),
        ('owner@example.com', '+12025550123', ''),
        ('owner@example.com', '+12025550123', 'not an alias'),
        (
          'owner@example.com',
          '+12025550123',
          List.generate(11, (i) => 'alias$i').join(','),
        ),
      ]) {
        expect(
          () => ScanIdentifiers(
            email: values.$1,
            phone: values.$2,
            aliases: values.$3,
          ),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'session refresh and controller retry preserve phone email and every alias',
    () async {
      final bodies = <Map<String, dynamic>>[];
      var refreshes = 0;
      final fixture = jsonDecode(
        File('test/footprint/fixtures/correlated_dashboard.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final scanId = fixture['scan_id'];
      final client = OsintClient(
        asyncTokenProvider: ({forceRefresh = false}) async {
          if (forceRefresh) refreshes++;
          return 'test-token';
        },
        httpClient: MockClient((request) async {
          if (request.method == 'POST') {
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            if (bodies.length == 1) return http.Response('{}', 401);
            if (bodies.length == 2) return http.Response('{}', 429);
            return http.Response(jsonEncode({'scan_id': scanId}), 202);
          }
          if (request.url.path.endsWith('/results')) {
            return http.Response(jsonEncode(fixture), 200);
          }
          return http.Response(
            jsonEncode({'scan_id': scanId, 'status': 'COMPLETED'}),
            200,
          );
        }),
      );
      final controller = FootprintController(
        BackendFootprintRepository(client: client),
      );
      addTearDown(controller.dispose);
      expect(
        await controller.scanIdentity(
          '+12025550123',
          associatedEmail: 'owner@example.com',
          associatedUsernames: ['owner', 'owner_dev'],
        ),
        isFalse,
      );
      expect(controller.profile, isNull);
      await controller.retry();
      expect(controller.error, isNull);
      expect(controller.profile?.osintReport?.scanId, scanId);
      expect(refreshes, 1);
      expect(bodies, hasLength(3));
      for (final body in bodies) {
        expect(body, {
          'target_type': 'phone',
          'identifier': '+12025550123',
          'associated_email': 'owner@example.com',
          'associated_usernames': ['owner', 'owner_dev'],
          'consent_self_audit': true,
        });
      }
    },
  );
}
