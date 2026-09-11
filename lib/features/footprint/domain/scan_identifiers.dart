import 'scan_target.dart';

/// One self-audit supplies the inputs required by all four deployed engines.
class ScanIdentifiers {
  ScanIdentifiers({
    required String email,
    required String phone,
    required String aliases,
  }) : email = validateEmail(email),
       phone = validatePhone(phone),
       aliases = List.unmodifiable(validateAliases(aliases));

  final String email;
  final String phone;
  final List<String> aliases;

  static String validateEmail(String value) {
    final clean = value.trim();
    if (!RegExp(r'^[^@\s]{1,64}@[^@\s]{1,255}\.[A-Za-z]{2,}$')
            .hasMatch(clean) ||
        clean.length > 254) {
      throw const FormatException(
        'Escribe tu correo, por ejemplo usuario@example.com.',
      );
    }
    return clean;
  }

  static String validatePhone(String value) {
    try {
      final target = ScanTarget.parse(value);
      if (target.type == 'phone' && target.identifier.length >= 9) {
        return target.identifier;
      }
    } on FormatException {
      // Show a field-specific correction without repeating personal data.
    }
    throw const FormatException(
      'Incluye +, código de país y entre 8 y 15 dígitos.',
    );
  }

  static List<String> validateAliases(String value) {
    final aliases = value
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (aliases.isEmpty ||
        aliases.length > 10 ||
        aliases.any((s) => !RegExp(r'^[A-Za-z0-9._-]{2,64}$').hasMatch(s))) {
      throw const FormatException(
        'Escribe de 1 a 10 alias separados por comas, de 2 a 64 letras, números, puntos, guiones o guiones bajos.',
      );
    }
    return aliases;
  }
}
