/// Phone numbers require an explicit international prefix to avoid mistaking
/// a numeric username for a phone number.
class ScanTarget {
  const ScanTarget._(this.type, this.identifier);
  final String type;
  final String identifier;

  factory ScanTarget.parse(String value) {
    final clean = value.trim();
    if (clean.length < 2 || clean.length > 120) {
      throw const FormatException('Usa entre 2 y 120 caracteres.');
    }
    if (clean.startsWith('+')) {
      final phone = clean.replaceAll(RegExp(r'[\s()-]'), '');
      if (!RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(phone)) {
        throw const FormatException(
          'Incluye +, código de país y entre 7 y 15 dígitos.',
        );
      }
      return ScanTarget._('phone', phone);
    }
    return ScanTarget._(clean.contains('@') ? 'email' : 'username', clean);
  }
}
