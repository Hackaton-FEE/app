import 'dart:convert';
import 'dart:io';

import 'package:fee_app/app/theme.dart';
import 'package:fee_app/features/accounts/domain/identity_profile.dart';
import 'package:fee_app/features/accounts/presentation/identity_profile_controller.dart';
import 'package:fee_app/features/auth/domain/user_profile.dart';
import 'package:fee_app/features/footprint/data/backend_footprint_repository.dart';
import 'package:fee_app/features/footprint/data/osint_client.dart';
import 'package:fee_app/features/footprint/domain/scan_identifiers.dart';
import 'package:fee_app/features/footprint/presentation/footprint_controller.dart';
import 'package:fee_app/features/footprint/presentation/widgets/correlation_graph.dart';
import 'package:fee_app/features/footprint/presentation/widgets/footprint_detail_sheet.dart';
import 'package:fee_app/features/footprint/presentation/widgets/scan_form_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/ready_identity_repository.dart';

void main() {
  testWidgets(
    'client inputs stay separate from login and each service keeps its username',
    (tester) async {
      final account = UserProfile.fromJson({
        'id': 'account-test',
        'label': 'login_alias',
        'created_at': '2026-09-10T12:00:00Z',
        'credentials_count': 1,
      }).toLocalAccount();
      expect(account.email, isEmpty);
      final identity = IdentityProfileController(
        ReadyIdentityRepository(),
        accountId: account.id,
      );
      await identity.save(
        IdentityProfile(
          accountId: account.id,
          mainIdentifier: 'client@example.invalid',
          associatedEmail: 'client@example.invalid',
          phone: '+12025550123',
          associatedUsernames: const ['client_seed'],
          createdAt: DateTime.utc(2026, 9, 10),
        ),
      );
      final fixture = jsonDecode(
        File('test/footprint/fixtures/correlated_dashboard.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final accounts = [
        ('Example Social', 'client_social'),
        ('Example Code', 'client_code'),
      ];
      fixture['categories'][0]['items_count'] = accounts.length;
      fixture['categories'][0]['items'] = [
        for (final (platform, username) in accounts)
          {
            'platform': platform,
            'username': username,
            'url': 'https://example.invalid/$username',
            'status': 'CONFIRMED',
            'confidence': 90,
            'sources': ['maigret'],
            'details': <String, dynamic>{},
          },
      ];
      for (var i = 0; i < accounts.length; i++) {
        fixture['correlation']['identity_graph']['nodes'][i]['username'] =
            accounts[i].$2;
      }
      fixture['correlation']['identity_graph']['edges'][0]['shared'] = [
        'masked_email',
      ];
      fixture['correlation']['timeline']['entries'][0]['username'] =
          accounts.first.$2;
      final requests = <Map<String, dynamic>>[];
      final controller = FootprintController(
        BackendFootprintRepository(
          targetIdentity: account.email,
          client: OsintClient(
            httpClient: MockClient((request) async {
              if (request.method == 'POST') {
                requests.add(jsonDecode(request.body) as Map<String, dynamic>);
                return http.Response('{"scan_id":"test-scan-id"}', 202);
              }
              if (request.url.path.endsWith('/results')) {
                return http.Response(jsonEncode(fixture), 200);
              }
              return http.Response(
                '{"scan_id":"test-scan-id","status":"COMPLETED"}',
                200,
              );
            }),
          ),
        ),
      );
      addTearDown(identity.dispose);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openScanForm(
                  context,
                  controller,
                  identityController: identity,
                  fallbackIdentity: account.email,
                ),
                child: Text(account.name),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text(account.name));
      await tester.pumpAndSettle();
      final submit = find.byKey(const Key('start-scan-submit-button'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(controller.error, isNull);
      expect(requests, [
        {
          'target_type': 'phone',
          'identifier': '+12025550123',
          'associated_email': 'client@example.invalid',
          'associated_usernames': ['client_seed'],
          'consent_self_audit': true,
        },
      ]);
      final profile = controller.profile!;
      expect(profile.targetIdentity, '+12025550123');
      expect(profile.items, hasLength(accounts.length));
      for (final (platform, username) in accounts) {
        final finding = profile.items.singleWhere(
          (item) => item.platform == platform,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: FootprintDetailSheet(item: finding, onCreateReport: (_) {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(platform), findsOneWidget);
        expect(find.text('• Usuario: $username'), findsOneWidget);
        expect(find.textContaining(account.name), findsNothing);
        expect(find.textContaining('Usuario: client_seed'), findsNothing);
        expect(find.textContaining('Usuario: username'), findsNothing);
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: CorrelationPage(correlation: profile.osintReport!.correlation!),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('correlation-account-picker')));
      await tester.pumpAndSettle();
      for (final (platform, username) in accounts) {
        expect(find.text('$platform · $username'), findsWidgets);
      }
      expect(find.textContaining(account.name), findsNothing);
      expect(find.textContaining(' · client_seed'), findsNothing);
      expect(find.textContaining(' · username'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
