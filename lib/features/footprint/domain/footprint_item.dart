import '../../cases/domain/privacy_case.dart';

enum FootprintCategory { socialProfile, exposedContact, dataBreach, dataBroker }

enum FootprintRisk { low, medium, high }

class FootprintItem {
  FootprintItem({
    required this.id,
    required this.platform,
    required this.category,
    required this.riskLevel,
    required this.title,
    required this.description,
    required Iterable<String> exposedData,
    required this.sourceUrl,
    required this.recommendedAction,
    this.suggestedCaseCategory = CaseCategory.personalData,
    this.rawDetails = const {},
    this.confidence = 80,
  }) : exposedData = List.unmodifiable(exposedData);

  final String id;
  final String platform;
  final FootprintCategory category;
  final FootprintRisk riskLevel;
  final String title;
  final String description;
  final List<String> exposedData;
  final String sourceUrl;
  final String recommendedAction;
  final CaseCategory suggestedCaseCategory;
  final Map<String, dynamic> rawDetails;
  final int confidence;
}
