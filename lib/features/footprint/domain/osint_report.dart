import 'footprint_correlation.dart';

class OsintReport {
  OsintReport({
    required this.scanId,
    required this.exposureScore,
    required this.riskLevel,
    required this.partial,
    required this.platformsFound,
    required this.highConfidence,
    required this.potentialMatches,
    required this.rateLimited,
    required Iterable<String> enginesRun,
    this.correlation,
  }) : enginesRun = List.unmodifiable(enginesRun);

  final String scanId;
  final int exposureScore;
  final String riskLevel;
  final bool partial;
  final int platformsFound;
  final int highConfidence;
  final int potentialMatches;
  final int rateLimited;
  final List<String> enginesRun;
  final FootprintCorrelation? correlation;
}
