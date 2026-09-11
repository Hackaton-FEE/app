import 'package:characters/characters.dart';

import 'guard_ai_profile_report.dart';

enum GuardAiRole { person, assistant }

class GuardAiUnavailable implements Exception {
  const GuardAiUnavailable();
}

class GuardAiMessage {
  const GuardAiMessage({
    required this.role,
    required this.text,
    this.recommendedAction,
    this.profileReport,
  });

  final GuardAiRole role;
  final String text;
  final String? recommendedAction;
  final GuardAiProfileReport? profileReport;
}

class GuardAiConversation {
  GuardAiConversation({
    Iterable<GuardAiMessage> messages = const [],
    Iterable<String> suggestions = const [],
    this.canPrepareReport = false,
    this.isSimulation = false,
  }) : messages = List.unmodifiable(messages),
       suggestions = List.unmodifiable(suggestions);

  final List<GuardAiMessage> messages;
  final List<String> suggestions;
  final bool canPrepareReport;
  final bool isSimulation;
}

class GuardAiInput {
  GuardAiInput(String value) : text = value.trim() {
    if (text.isEmpty || text.characters.length > maxLength) {
      throw const FormatException('Mensaje fuera del límite permitido.');
    }
  }

  static const maxLength = 1000;
  final String text;
}

/// A successful reply returns the entire committed conversation.
/// Implementations must leave it unchanged when an operation fails.
abstract interface class GuardAiRepository {
  Future<GuardAiConversation> loadConversation();

  Future<GuardAiConversation> reply(GuardAiInput input);
}
