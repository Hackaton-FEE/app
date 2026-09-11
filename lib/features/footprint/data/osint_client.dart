import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/scan_target.dart';

/// Modelo que encapsula el avance y estado de un escaneo OSINT.
class OsintProgress {
  const OsintProgress({
    required this.scanId,
    required this.status,
    required this.progressPercentage,
    required this.completedEngines,
    required this.runningEngines,
    required this.partialFindingsCount,
  });

  factory OsintProgress.fromJson(Map<String, dynamic> json) {
    return OsintProgress(
      scanId: json['scan_id'] as String? ?? '',
      status: json['status'] as String? ?? 'UNKNOWN',
      progressPercentage: (json['progress_percentage'] as num?)?.toInt() ?? 0,
      completedEngines:
          (json['completed_engines'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      runningEngines:
          (json['running_engines'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      partialFindingsCount:
          (json['partial_findings_count'] as num?)?.toInt() ?? 0,
    );
  }

  final String scanId;
  final String status;
  final int progressPercentage;
  final List<String> completedEngines;
  final List<String> runningEngines;
  final int partialFindingsCount;

  bool get isDone => status == 'COMPLETED' || status == 'FAILED';
  bool get isFailed => status == 'FAILED';
}

typedef AsyncTokenProvider = Future<String?> Function({bool forceRefresh});

/// Cliente HTTP para consumir los endpoints del motor OSINT de FastAPI v0.2.0.
class OsintClient {
  OsintClient({
    this.baseUrl = 'https://backosisnt.ici-labs.com/api/v1',
    String? accessToken,
    String? Function()? tokenProvider,
    this._asyncTokenProvider,
    http.Client? httpClient,
  }) : _tokenProvider = tokenProvider ?? (() => accessToken),
       _client = httpClient ?? http.Client();

  final String baseUrl;
  final String? Function() _tokenProvider;
  final AsyncTokenProvider? _asyncTokenProvider;
  final http.Client _client;

  String get accessToken => _tokenProvider() ?? '';

  static const _timeout = Duration(seconds: 45);

  Future<Map<String, String>> _getHeaders({bool forceRefresh = false}) async {
    var token = forceRefresh ? '' : accessToken.trim();
    if (token.isEmpty && _asyncTokenProvider != null) {
      final ensured = await _asyncTokenProvider(forceRefresh: forceRefresh);
      if (ensured != null && ensured.isNotEmpty) token = ensured.trim();
    }
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'User-Agent': 'fee_app/0.1.0',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Dispara el escaneo OSINT en segundo plano y devuelve el scan_id asignado.
  Future<String> startScan({
    required String mainIdentifier,
    List<String> associatedUsernames = const [],
    String? associatedEmail,
    bool consentSelfAudit = true,
  }) async {
    final target = ScanTarget.parse(mainIdentifier);
    final cleanId = target.identifier;
    final isEmail = target.type == 'email';

    var headers = await _getHeaders();
    var response = await _client
        .post(
          Uri.parse('$baseUrl/osint/scans'),
          headers: headers,
          body: jsonEncode({
            'target_type': target.type,
            'identifier': cleanId,
            'associated_usernames': associatedUsernames,
            'associated_email': associatedEmail ?? (isEmail ? cleanId : null),
            'consent_self_audit': consentSelfAudit,
          }),
        )
        .timeout(_timeout);

    // Si recibimos 401 por sesión inválida y contamos con asyncTokenProvider, re-autenticar y reintentar
    if (response.statusCode == 401 && _asyncTokenProvider != null) {
      headers = await _getHeaders(forceRefresh: true);
      response = await _client
          .post(
            Uri.parse('$baseUrl/osint/scans'),
            headers: headers,
            body: jsonEncode({
              'target_type': target.type,
              'identifier': cleanId,
              'associated_usernames': associatedUsernames,
              'associated_email': associatedEmail ?? (isEmail ? cleanId : null),
              'consent_self_audit': consentSelfAudit,
            }),
          )
          .timeout(_timeout);
    }

    if (response.statusCode == 202) {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return data['scan_id'] as String;
    }

    _handleError(response);
  }

  /// Consulta periódica del avance hasta que el estado sea COMPLETED o FAILED.
  Stream<OsintProgress> pollProgress(
    String scanId, {
    Duration interval = const Duration(seconds: 2),
    int maxPolls = 120,
  }) async* {
    var polls = 0;
    while (polls < maxPolls) {
      polls++;
      var headers = await _getHeaders();
      var response = await _client
          .get(Uri.parse('$baseUrl/osint/scans/$scanId'), headers: headers)
          .timeout(_timeout);

      if (response.statusCode == 401 && _asyncTokenProvider != null) {
        headers = await _getHeaders(forceRefresh: true);
        response = await _client
            .get(Uri.parse('$baseUrl/osint/scans/$scanId'), headers: headers)
            .timeout(_timeout);
      }

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final progress = OsintProgress.fromJson(data);
        yield progress;

        if (progress.isFailed) {
          throw const FormatException('El escaneo falló. Puedes reintentarlo.');
        }
        if (progress.isDone) return;
      } else {
        _handleError(response);
      }

      if (polls < maxPolls) await Future<void>.delayed(interval);
    }
    throw TimeoutException('El escaneo sigue pendiente. Inténtalo más tarde.');
  }

  /// Descarga el dashboard consolidado de hallazgos para el scan_id completado.
  Future<Map<String, dynamic>> fetchResults(String scanId) async {
    var headers = await _getHeaders();
    var response = await _client
        .get(
          Uri.parse('$baseUrl/osint/scans/$scanId/results'),
          headers: headers,
        )
        .timeout(_timeout);

    if (response.statusCode == 401 && _asyncTokenProvider != null) {
      headers = await _getHeaders(forceRefresh: true);
      response = await _client
          .get(
            Uri.parse('$baseUrl/osint/scans/$scanId/results'),
            headers: headers,
          )
          .timeout(_timeout);
    }

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }

    _handleError(response);
  }

  /// Elimina los resultados del escaneo en el servidor.
  Future<void> deleteScan(String scanId) async {
    final headers = await _getHeaders();
    final response = await _client
        .delete(Uri.parse('$baseUrl/osint/scans/$scanId'), headers: headers)
        .timeout(_timeout);

    if (response.statusCode != 204 && response.statusCode != 200) {
      _handleError(response);
    }
  }

  Never _handleError(http.Response response) {
    String? serverDetail;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic> && body['detail'] is String) {
        final d = (body['detail'] as String).trim();
        if (d.isNotEmpty && !d.contains('\n')) {
          serverDetail = d;
        }
      }
    } catch (_) {}

    final message = switch (response.statusCode) {
      400 || 422 =>
        serverDetail ?? 'Revisa el identificador y el consentimiento del escaneo.',
      401 => 'Sesión no autorizada o expirada. Vuelve a iniciar sesión.',
      403 => serverDetail ?? 'No tienes acceso a este escaneo.',
      404 => serverDetail ?? 'El escaneo ya no está disponible.',
      409 => serverDetail ?? 'El escaneo aún no está listo. Inténtalo más tarde.',
      429 =>
        'Límite de escaneos alcanzado en el servidor. Inténtalo más tarde.',
      _ => 'No se pudo completar la consulta al servidor OSINT.',
    };
    throw FormatException(message);
  }
}

