import 'dart:async';

import '../../cases/domain/privacy_case.dart';
import '../domain/footprint_item.dart';
import '../domain/footprint_profile.dart';
import '../domain/footprint_repository.dart';
import '../domain/resumable_footprint_repository.dart';
import 'pending_scan_store.dart';
import 'finding_presentation_mapper.dart';
import '../domain/scan_history_repository.dart';
import 'osint_client.dart';
import 'osint_dashboard_payload.dart';

/// Implementación de [FootprintRepository] conectada al motor OSINT real de FastAPI v0.2.0.
class BackendFootprintRepository
    implements FootprintRepository, ResumableFootprintRepository {
  BackendFootprintRepository({
    required this.client,
    this.targetIdentity,
    this._historyRepository,
    this.onProgressUpdate,
    this.pendingStore,
  });

  final OsintClient client;
  final String? targetIdentity;
  final ScanHistoryRepository? _historyRepository;
  final void Function(String stage, int percentage)? onProgressUpdate;

  final PendingScanStore? pendingStore;
  PendingScan? _pendingScan;
  Future<FootprintProfile?>? _active;
  FootprintProfile? _currentProfile;
  FootprintProfile? _pendingResult;

  @override
  void setForeground(bool foreground) =>
      client.activity.setForeground(foreground);

  Future<FootprintProfile?> _exclusive(
    Future<FootprintProfile?> Function() run,
  ) {
    if (_active != null) return _active!;
    final future = run();
    _active = future;
    return future.whenComplete(() => _active = null);
  }

  @override
  Future<FootprintProfile?> resumePendingScan() => _exclusive(() async {
    _pendingScan ??= await pendingStore?.load();
    final pending = _pendingScan;
    if (pending == null) return null;
    await pendingStore?.save(pending);
    return _recover(pending);
  });

  @override
  Future<void> acknowledgeScan(String scanId) async {
    if (_pendingScan?.id != scanId) return;
    await pendingStore?.clear();
    _pendingScan = null;
    _currentProfile = _pendingResult ?? _currentProfile;
    _pendingResult = null;
  }

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
    String? associatedEmail,
    bool consentSelfAudit = true,
  }) async => (await _exclusive(() async {
    _pendingScan ??= await pendingStore?.load();
    if (_pendingScan case final pending?) {
      await pendingStore?.save(pending);
      return _recover(pending);
    }
    return _startScan(
      identity,
      associatedUsernames,
      associatedEmail,
      consentSelfAudit,
    );
  }))!;

  Future<FootprintProfile> _startScan(
    String identity,
    List<String> associatedUsernames,
    String? associatedEmail,
    bool consentSelfAudit,
  ) async {
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
      associatedEmail: associatedEmail ?? (isEmail ? cleanIdentity : null),
      consentSelfAudit: consentSelfAudit,
    );

    if (pendingStore != null) {
      _pendingScan = PendingScan(scanId, cleanIdentity);
      await pendingStore!.save(_pendingScan!);
    }
    return _recover(PendingScan(scanId, cleanIdentity));
  }

  Future<FootprintProfile> _recover(PendingScan pending) async {
    try {
      return await _collect(pending.identity, pending.id);
    } on OsintScanEndedException {
      _pendingResult = null;
      await acknowledgeScan(pending.id);
      rethrow;
    }
  }

  Future<FootprintProfile> _collect(String cleanIdentity, String scanId) async {
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
    if (rawResults['scan_id'] != scanId) {
      throw const FormatException(
        'El resultado no corresponde al escaneo pendiente.',
      );
    }
    final profile = _parseDashboardResult(cleanIdentity, rawResults);
    if (pendingStore == null) {
      _currentProfile = profile;
    } else {
      _pendingResult = profile;
    }
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

        final category = mapFindingCategory(
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

        final riskLevel = mapFindingRisk(status, confidence);
        final title = status == 'POTENTIAL_MATCH'
            ? 'Posible coincidencia en $platform'
            : details['full_name'] != null
            ? 'Hallazgo público con nombre "${details['full_name']}"'
            : 'Hallazgo público en $platform';

        final desc =
            'Señal detectada por ${sources.join(', ')}. '
            'Confianza reportada: $confidence%. '
            'No confirma titularidad ni actividad reciente.';

        final recommendedAction = recommendedFindingAction(category, platform);

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
}
