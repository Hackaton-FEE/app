/// Validates a user-provided link without opening it or sending it anywhere.
Uri parseSourceLink(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !const {'https', 'http'}.contains(uri.scheme) ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.host.contains(RegExp(r'[%\s]'))) {
    throw const FormatException(
      'Introduce un enlace válido con https:// o http://.',
    );
  }
  return uri;
}
