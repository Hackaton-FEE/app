/// Parses persisted/API timestamps without normalizing impossible dates.
DateTime parseProfileDate(dynamic value) {
  if (value is! String) throw const FormatException('Fecha inválida.');
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})'
    r'(?:\.\d{1,6})?(?:Z|[+-](\d{2}):(\d{2}))?$',
  ).firstMatch(value);
  if (match == null) throw const FormatException('Fecha inválida.');
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > DateTime.utc(year, month + 1, 0).day ||
      int.parse(match[4]!) > 23 ||
      int.parse(match[5]!) > 59 ||
      int.parse(match[6]!) > 59 ||
      (match[7] != null && int.parse(match[7]!) > 23) ||
      (match[8] != null && int.parse(match[8]!) > 59)) {
    throw const FormatException('Fecha inválida.');
  }
  return DateTime.parse(value);
}
