import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
      completedEngines: (json['completed_engines'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      runningEngines: (json['running_engines'] as List<dynamic>?)
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

/// Cliente HTTP para consumir los endpoints del motor OSINT de FastAPI v0.2.0.
class OsintClient {
  OsintClient({
    this.baseUrl = 'https://backosisnt.ici-labs.com/api/v1',
    required this.accessToken,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  final String baseUrl;
  final String accessToken;
  final http.Client _client;

  static const _timeout = Duration(seconds: 30);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'User-Agent': 'fee_app/0.1.0',
        'Authorization': 'Bearer $accessToken',
      };

  /// Dispara el escaneo OSINT en segundo plano y devuelve el scan_id asignado.
  Future<String> startScan({
    required String mainIdentifier,
    List<String> associatedUsernames = const [],
    String? associatedEmail,
    bool consentSelfAudit = true,
  }) async {
    final cleanId = mainIdentifier.trim();
    final isEmail = cleanId.contains('@');

    final response = await _client
        .post(
          Uri.parse('$baseUrl/osint/scans'),
          headers: _headers,
          body: jsonEncode({
            'target_type': isEmail ? 'email' : 'username',
            'identifier': cleanId,
            'associated_usernames': associatedUsernames,
            'associated_email':
                associatedEmail ?? (isEmail ? cleanId : null),
            'consent_self_audit': consentSelfAudit,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 202) {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return data['scan_id'] as String;
    }

    _handleError(response);
    throw Exception('Error inesperado al iniciar escaneo: ${response.statusCode}');
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
      final response = await _client
          .get(
            Uri.parse('$baseUrl/osint/scans/$scanId'),
            headers: _headers,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final progress = OsintProgress.fromJson(data);
        yield progress;

        if (progress.isDone) {
          break;
        }
      } else {
        _handleError(response);
      }

      await Future<void>.delayed(interval);
    }
  }

  /// Descarga el dashboard consolidado de hallazgos para el scan_id completado.
  Future<Map<String, dynamic>> fetchResults(String scanId) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/osint/scans/$scanId/results'),
          headers: _headers,
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }

    _handleError(response);
    throw Exception(
        'Error inesperado al descargar resultados: ${response.statusCode}');
  }

  /// Elimina los resultados del escaneo en el servidor.
  Future<void> deleteScan(String scanId) async {
    final response = await _client
        .delete(
          Uri.parse('$baseUrl/osint/scans/$scanId'),
          headers: _headers,
        )
        .timeout(_timeout);

    if (response.statusCode != 204 && response.statusCode != 200) {
      _handleError(response);
    }
  }

  void _handleError(http.Response response) {
    try {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final detail = data['detail'];
      if (detail is String) {
        throw Exception(detail);
      }
      if (detail is Map<String, dynamic>) {
        final msg = detail['message'] as String? ?? 'Error en el servidor.';
        throw Exception(msg);
      }
    } catch (e) {
      if (e is Exception && !e.toString().contains('FormatException')) {
        rethrow;
      }
    }
    throw Exception('Error del servidor OSINT (${response.statusCode}).');
  }
}
