import 'package:characters/characters.dart';

enum GuardAiRole { person, assistant }

class GuardAiMessage {
  const GuardAiMessage({required this.role, required this.text});

  final GuardAiRole role;
  final String text;
}

class GuardAiConversation {
  GuardAiConversation({
    Iterable<GuardAiMessage> messages = const [],
    Iterable<String> suggestions = const [],
    this.canPrepareReport = false,
  }) : messages = List.unmodifiable(messages),
       suggestions = List.unmodifiable(suggestions);

  final List<GuardAiMessage> messages;
  final List<String> suggestions;
  final bool canPrepareReport;
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
