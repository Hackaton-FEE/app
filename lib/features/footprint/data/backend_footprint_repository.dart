import 'dart:async';

import '../../cases/domain/privacy_case.dart';
import '../domain/footprint_item.dart';
import '../domain/footprint_profile.dart';
import '../domain/footprint_repository.dart';
import 'mock_footprint_repository.dart';
import 'osint_client.dart';

/// Implementación de [FootprintRepository] conectada al motor OSINT real de FastAPI v0.2.0.
class BackendFootprintRepository implements FootprintRepository {
  BackendFootprintRepository({
    required this.client,
    FootprintRepository? fallbackRepository,
    this.onProgressUpdate,
  }) : _fallback = fallbackRepository ?? MockFootprintRepository();

  final OsintClient client;
  final FootprintRepository _fallback;
  final void Function(String stage, int percentage)? onProgressUpdate;

  FootprintProfile? _currentProfile;

  @override
  Future<FootprintProfile> getProfile() async {
    if (_currentProfile != null) {
      return _currentProfile!;
    }
    return _fallback.getProfile();
  }

  @override
  Future<FootprintProfile> scanIdentity(String identity) async {
    final cleanIdentity = identity.trim();
    if (cleanIdentity.isEmpty) {
      throw const FormatException('Ingresa un correo o alias válido.');
    }

    try {
      onProgressUpdate?.call('Encolando auditoría en el motor OSINT…', 5);

      final isEmail = cleanIdentity.contains('@');
      final scanId = await client.startScan(
        mainIdentifier: cleanIdentity,
        associatedEmail: isEmail ? cleanIdentity : null,
        consentSelfAudit: true,
      );

      onProgressUpdate?.call('Escaneando en cascada (Blackbird, Maigret, Holehe)…', 15);

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
    } catch (e) {
      // Si la llamada remota falla y es un entorno de prueba/offline, permitir fallback seguro
      if (_currentProfile != null) {
        return _currentProfile!;
      }
      rethrow;
    }
  }

  FootprintProfile _parseDashboardResult(
    String identity,
    Map<String, dynamic> data,
  ) {
    final categoriesData = data['categories'] as List<dynamic>? ?? const [];
    final items = <FootprintItem>[];
    var counter = 0;

    for (final catJson in categoriesData) {
      if (catJson is! Map<String, dynamic>) continue;
      final catName = catJson['name'] as String? ?? 'general';
      final catItems = catJson['items'] as List<dynamic>? ?? const [];

      for (final itemJson in catItems) {
        if (itemJson is! Map<String, dynamic>) continue;
        counter++;

        final platform = itemJson['platform'] as String? ?? 'Plataforma';
        final username = itemJson['username'] as String?;
        final url = itemJson['url'] as String? ?? '';
        final status = itemJson['status'] as String? ?? 'CONFIRMED';
        final confidence = (itemJson['confidence'] as num?)?.toInt() ?? 80;
        final sources = (itemJson['sources'] as List<dynamic>?)
                ?.map((s) => s.toString())
                .toList() ??
            const [];
        final details = itemJson['details'] as Map<String, dynamic>? ?? const {};

        final category = _mapCategory(
          catName,
          platform: platform,
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
        final title = details['full_name'] != null
            ? 'Cuenta pública vinculada a "${details['full_name']}"'
            : 'Perfil público detectado en $platform';

        final desc = url.isNotEmpty
            ? 'Cuenta activa y accesible en $url detectada por ${sources.join(', ')}.'
            : 'Registro activo en $platform detectado con certeza del $confidence%.';

        final recommendedAction = _recommendedActionFor(category, platform);

        items.add(
          FootprintItem(
            id: 'osint-$counter-${DateTime.now().millisecondsSinceEpoch}',
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
      items: items.isEmpty
          ? _fallbackProfileItems(identity)
          : items,
      lastScannedAt: DateTime.now(),
    );
  }

  List<FootprintItem> _fallbackProfileItems(String identity) {
    return [
      FootprintItem(
        id: 'clean-1',
        platform: 'Superficie de Exposición',
        category: FootprintCategory.socialProfile,
        riskLevel: FootprintRisk.low,
        title: 'Baja exposición pública detectada',
        description: 'No se encontraron filtraciones críticas inmediatas para "$identity".',
        exposedData: ['Identificador auditado: $identity'],
        sourceUrl: '',
        recommendedAction: 'Mantén contraseñas seguras y monitorea periódicamente tu huella.',
        suggestedCaseCategory: CaseCategory.personalData,
      ),
    ];
  }

  FootprintCategory _mapCategory(
    String name, {
    String platform = '',
    List<String> sources = const [],
    Map<String, dynamic> details = const {},
  }) {
    final lowerCat = name.toLowerCase();

    // Verificaciones de correo / teléfono o motor Holehe -> Contacto
    if (sources.contains('holehe') ||
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
      FootprintCategory.dataBreach =>
        'Cambiar la contraseña inmediatamente y habilitar autenticación multifactor.',
      FootprintCategory.dataBroker =>
        'Generar un reclamo formal de desindexación y retiro de registros en $platform.',
      FootprintCategory.exposedContact =>
        'Ocultar teléfonos y correos en los ajustes de privacidad de recuperación.',
      FootprintCategory.socialProfile =>
        'Revisar la visibilidad de tu perfil en $platform y restringir datos personales públicos.',
    };
  }
}
