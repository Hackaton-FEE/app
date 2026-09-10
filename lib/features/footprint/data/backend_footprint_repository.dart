import 'dart:async';

import '../../cases/domain/privacy_case.dart';
import '../domain/footprint_item.dart';
import '../domain/footprint_profile.dart';
import '../domain/footprint_repository.dart';
import '../domain/scan_history_repository.dart';
import 'osint_client.dart';
import 'osint_dashboard_payload.dart';

/// Implementación de [FootprintRepository] conectada al motor OSINT real de FastAPI v0.2.0.
class BackendFootprintRepository implements FootprintRepository {
  BackendFootprintRepository({
    required this.client,
    this.targetIdentity,
    this._historyRepository,
    this.onProgressUpdate,
  });

  final OsintClient client;
  final String? targetIdentity;
  final ScanHistoryRepository? _historyRepository;
  final void Function(String stage, int percentage)? onProgressUpdate;

  FootprintProfile? _currentProfile;

  @override
  Future<FootprintProfile> getProfile() async {
    if (_currentProfile != null) {
      return _currentProfile!;
    }
    if (_historyRepository != null) {
      final entries = await _historyRepository.loadHistory();
      final target = targetIdentity?.trim().toLowerCase();
      for (final entry in entries) {
        if (!entry.hasBackendReport) continue;
        if (target == null ||
            target.isEmpty ||
            entry.targetIdentity.trim().toLowerCase() == target) {
          _currentProfile = entry.toProfile();
          return _currentProfile!;
        }
      }
    }

    if (targetIdentity != null && targetIdentity!.trim().isNotEmpty) {
      return FootprintProfile.initial(targetIdentity: targetIdentity!.trim());
    }
    return FootprintProfile.initial(targetIdentity: '');
  }

  @override
  Future<FootprintProfile> scanIdentity(
    String identity, {
    List<String> associatedUsernames = const [],
    bool consentSelfAudit = true,
  }) async {
    final cleanIdentity = identity.trim();
    if (cleanIdentity.isEmpty) {
      throw const FormatException(
        'Ingresa un correo, alias o teléfono válido.',
      );
    }

    onProgressUpdate?.call('Encolando auditoría en el motor OSINT…', 5);

    final isEmail = cleanIdentity.contains('@');
    final scanId = await client.startScan(
      mainIdentifier: cleanIdentity,
      associatedUsernames: associatedUsernames,
      associatedEmail: isEmail ? cleanIdentity : null,
      consentSelfAudit: consentSelfAudit,
    );

    onProgressUpdate?.call(
      'Consultando las fuentes disponibles para este identificador…',
      15,
    );

    await for (final progress in client.pollProgress(scanId)) {
      final pct = progress.progressPercentage.clamp(15, 95);
      final running = progress.runningEngines.isNotEmpty
          ? ' (${progress.runningEngines.join(', ')})'
          : '';
      onProgressUpdate?.call('Consultando plataformas$running… $pct%', pct);
    }

    onProgressUpdate?.call('Consolidando resultados y deduplicando…', 98);
    final rawResults = await client.fetchResults(scanId);

    final profile = _parseDashboardResult(cleanIdentity, rawResults);
    _currentProfile = profile;
    onProgressUpdate?.call('Diagnóstico de huella completado', 100);
    return profile;
  }

  FootprintProfile _parseDashboardResult(
    String identity,
    Map<String, dynamic> data,
  ) {
    final dashboard = OsintDashboardPayload.fromJson(data);
    final report = dashboard.report;
    final items = <FootprintItem>[];
    var counter = 0;

    for (final categoryData in dashboard.categories) {
      for (final finding in categoryData.items) {
        counter++;
        // The entire payload, including blocked checks, was validated above.
        if (finding.status == 'RATE_LIMITED') continue;
        final platform = finding.platform;
        final username = finding.username;
        final url = finding.url ?? '';
        final status = finding.status;
        final confidence = finding.confidence;
        final sources = finding.sources;
        final details = finding.details;

        final category = _mapCategory(
          categoryData.name,
          sources: sources,
          details: details,
        );

        final exposedDataList = <String>[];
        if (username != null && username.isNotEmpty) {
          exposedDataList.add('Usuario: $username');
        }
        if (details['full_name'] != null) {
          exposedDataList.add('Nombre: ${details['full_name']}');
        }
        if (details['location'] != null &&
            details['location'].toString().trim().isNotEmpty) {
          exposedDataList.add('Ubicación: ${details['location']}');
        }
        if (details['masked_email'] != null) {
          exposedDataList.add('Correo: ${details['masked_email']}');
        }
        if (details['masked_phone'] != null) {
          exposedDataList.add('Teléfono: ${details['masked_phone']}');
        }
        if (details['company'] != null) {
          exposedDataList.add('Empresa: ${details['company']}');
        }
        if (details['account_id'] != null) {
          exposedDataList.add('ID de cuenta: ${details['account_id']}');
        }
        if (details['followers'] != null) {
          exposedDataList.add('Seguidores: ${details['followers']}');
        }
        if (details['creation_date'] != null) {
          exposedDataList.add('Registro: ${details['creation_date']}');
        }
        if (exposedDataList.isEmpty) {
          exposedDataList.add('Presencia pública indexada');
        }

        final riskLevel = _mapRisk(status, confidence);
        final title = status == 'POTENTIAL_MATCH'
            ? 'Posible coincidencia en $platform'
            : details['full_name'] != null
            ? 'Hallazgo público con nombre "${details['full_name']}"'
            : 'Hallazgo público en $platform';

        final desc =
            'Señal detectada por ${sources.join(', ')}. '
            'Confianza reportada: $confidence%. '
            'No confirma titularidad ni actividad reciente.';

        final recommendedAction = _recommendedActionFor(category, platform);

        items.add(
          FootprintItem(
            id: '${report.scanId}-$counter',
            platform: platform,
            category: category,
            riskLevel: riskLevel,
            title: title,
            description: desc,
            exposedData: exposedDataList,
            sourceUrl: url,
            recommendedAction: recommendedAction,
            suggestedCaseCategory: CaseCategory.personalData,
            rawDetails: details,
            confidence: confidence,
          ),
        );
      }
    }

    return FootprintProfile(
      targetIdentity: identity,
      items: items,
      lastScannedAt: dashboard.generatedAt.toLocal(),
      osintReport: report,
    );
  }

  FootprintCategory _mapCategory(
    String name, {
    required List<String> sources,
    required Map<String, dynamic> details,
  }) {
    final lowerCat = name.toLowerCase();

    // Verificaciones de correo / teléfono o motor Holehe -> Contacto
    if (sources.contains('holehe') ||
        sources.contains('ignorant') ||
        details['masked_email'] != null ||
        details['masked_phone'] != null ||
        lowerCat.contains('contact') ||
        lowerCat.contains('phone') ||
        lowerCat.contains('messaging') ||
        lowerCat.contains('email')) {
      return FootprintCategory.exposedContact;
    }

    // Filtraciones / leaks / darkweb
    if (lowerCat.contains('breach') ||
        lowerCat.contains('leak') ||
        lowerCat.contains('pwned') ||
        lowerCat.contains('password') ||
        lowerCat.contains('pastebin') ||
        lowerCat.contains('darkweb')) {
      return FootprintCategory.dataBreach;
    }

    // Redes sociales, plataformas de desarrollo, gaming, hobbies
    if (lowerCat.contains('social') ||
        lowerCat.contains('coding') ||
        lowerCat.contains('forum') ||
        lowerCat.contains('tech') ||
        lowerCat.contains('gaming') ||
        lowerCat.contains('music') ||
        lowerCat.contains('hobby')) {
      return FootprintCategory.socialProfile;
    }

    // Directorios, finanzas, brokers, dominios y registros públicos
    if (lowerCat.contains('broker') ||
        lowerCat.contains('search') ||
        lowerCat.contains('lookup') ||
        lowerCat.contains('finance') ||
        lowerCat.contains('domain') ||
        lowerCat.contains('adult') ||
        lowerCat.contains('other')) {
      return FootprintCategory.dataBroker;
    }

    return FootprintCategory.socialProfile;
  }

  FootprintRisk _mapRisk(String status, int confidence) {
    if (status == 'CONFIRMED' && confidence >= 85) {
      return FootprintRisk.high;
    }
    if (confidence >= 60 || status == 'POTENTIAL_MATCH') {
      return FootprintRisk.medium;
    }
    return FootprintRisk.low;
  }

  String _recommendedActionFor(FootprintCategory category, String platform) {
    return switch (category) {
      FootprintCategory.dataBreach => 'Cambiar la contraseña inmediatamente y habilitar autenticación multifactor.',
      FootprintCategory.dataBroker =>
        'Generar un reclamo formal de desindexación y retiro de registros en $platform.',
      FootprintCategory.exposedContact => 'Ocultar teléfonos y correos en los ajustes de privacidad de recuperación.',
      FootprintCategory.socialProfile =>
        'Revisar la visibilidad de tu perfil en $platform y restringir datos personales públicos.',
    };
  }
}
