import 'dart:convert';

import 'package:fee_app/features/footprint/domain/footprint_profile.dart';
import 'package:fee_app/features/footprint/domain/footprint_item.dart';
import 'package:fee_app/features/footprint/domain/osint_report.dart';
import 'package:fee_app/features/guard_ai/data/assistant_client.dart';
import 'package:fee_app/features/guard_ai/data/backend_guard_ai_repository.dart';
import 'package:fee_app/features/guard_ai/data/guard_ai_report_context.dart';
import 'package:fee_app/features/guard_ai/presentation/guard_ai_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

FootprintProfile profile(String id, int score) => FootprintProfile(
  targetIdentity: '$id@example.com',
  items: [
    FootprintItem(
      id: '$id-finding',
      platform: 'Plataforma $id',
      category: FootprintCategory.socialProfile,
      riskLevel: FootprintRisk.medium,
      title: 'Perfil público $id',
      description: 'Coincidencia pendiente de revisar.',
      exposedData: ['Usuario: alias_$id'],
      sourceUrl: 'https://example.com/$id',
      recommendedAction: 'Revisa quién puede ver el perfil.',
    ),
  ],
  lastScannedAt: DateTime.utc(2026, 9, 11),
  osintReport: OsintReport(
    scanId: id,
    exposureScore: score,
    riskLevel: 'MODERATE',
    partial: true,
    platformsFound: 1,
    highConfidence: 0,
    potentialMatches: 0,
    rateLimited: 3,
    enginesRun: ['holehe', 'maigret'],
  ),
);

void main() {
  test('current dashboard report is refreshed per turn without storing it as chat text', () async {
    FootprintProfile? current = profile('first', 31);
    final sent = <List<dynamic>>[];
    final repository = BackendGuardAiRepository(
      currentProfile: () => current,
      client: AssistantClient(
        httpClient: MockClient.streaming((request, body) async {
          sent.add(
            (jsonDecode(await body.bytesToString()) as Map)['messages'] as List,
          );
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                'event: token\ndata: {"content":"Revisa las consultas limitadas."}\n\nevent: done\ndata: {}\n\n',
              ),
            ),
            200,
          );
        }),
      ),
    );
    final controller = GuardAiController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    controller.setDraft('Borrador sin enviar');
    expect(await controller.sendQuickPrompt('Revisar mi perfil'), isTrue);
    expect(controller.draft, 'Borrador sin enviar');
    expect(sent.first.first['content'], contains('"exposicion":31'));
    expect(sent.first.first['content'], contains('"parcial":true'));
    current = profile('second', 57);
    await controller.sendQuickPrompt('Ayúdame con una recomendación');
    expect(
      controller.conversation.messages.last.recommendedAction,
      'Revisa quién puede ver el perfil.',
    );
    final context = sent.last[sent.last.length - 2]['content'] as String;
    expect(context, contains('"scan_id":"second"'));
    expect(context, contains('"exposicion":57'));
    expect(context, contains('Usuario: alias_second'));
    expect(context, contains('Plataforma second'));
    expect(context, isNot(contains('first@example.com')));
    expect(
      controller.conversation.messages.any(
        (message) => message.text.contains('scan_id'),
      ),
      isFalse,
    );
    current = null;
    await controller.sendQuickPrompt('Revisar mi perfil');
    expect(
      sent.last[sent.last.length - 2]['content'],
      contains('No hay un informe'),
    );
  });

  test('initial identity does not produce invented scan data', () {
    final text = guardAiReportContext(
      FootprintProfile.initial(targetIdentity: 'owner'),
    );
    expect(text, contains('No hay un informe'));
    expect(text, isNot(contains('exposicion')));
  });

  test('context stays within the server message limit even with oversized metadata', () {
    final text = guardAiReportContext(profile('long-value' * 2000, 42));
    expect(text.length, lessThan(4000));
    expect(text, contains('"exposicion":42'));
  });
}
