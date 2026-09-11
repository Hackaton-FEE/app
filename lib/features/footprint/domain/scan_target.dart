/// Represents a validated target identifier for OSINT footprint scans.
///
/// Supports email, international phone numbers, social usernames/aliases,
/// and full names matching the backend API contract.
class ScanTarget {
  const ScanTarget._(this.type, this.identifier);

  final String type;
  final String identifier;

  static final _phoneCleanRegex = RegExp(r'[\s()-]');
  static final _phoneRegex = RegExp(r'^\+[1-9][0-9]{6,14}$');
  static final _emailRegex = RegExp(
    r'^[^@\s]{1,64}@[^@\s]{1,255}\.[A-Za-z]{2,}$',
  );
  static final _usernameRegex = RegExp(r'^[A-Za-z0-9._-]{2,64}$');
  static final _nameRegex = RegExp(
    r"^[a-zA-Z\u00C0-\u024F\u1E00-\u1EFF](?:[a-zA-Z\u00C0-\u024F\u1E00-\u1EFF]|[ .'\-]){1,79}$",
  );

  factory ScanTarget.parse(String value) {
    final clean = value.trim();
    if (clean.length < 2 || clean.length > 120) {
      throw const FormatException('Usa entre 2 y 120 caracteres.');
    }
    if (clean.startsWith('+')) {
      final phone = clean.replaceAll(_phoneCleanRegex, '');
      if (!_phoneRegex.hasMatch(phone)) {
        throw const FormatException(
          'Incluye +, código de país y entre 7 y 15 dígitos.',
        );
      }
      return ScanTarget._('phone', phone);
    }
    if (clean.contains('@')) {
      if (!_emailRegex.hasMatch(clean)) {
        throw const FormatException(
          'Ingresa un correo electrónico válido (ej. usuario@dominio.com).',
        );
      }
      return ScanTarget._('email', clean);
    }
    if (_usernameRegex.hasMatch(clean)) {
      return ScanTarget._('username', clean);
    }
    if (_nameRegex.hasMatch(clean)) {
      return ScanTarget._('name', clean);
    }
    throw const FormatException(
      'Ingresa un alias sin espacios (ej. usuario_123), un correo válido, tu nombre o un teléfono.',
    );
  }
}

