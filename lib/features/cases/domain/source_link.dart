const maxSourceLinkLength = 2048;

/// Validates a user-provided link without opening it or sending it anywhere.
Uri parseSourceLink(String value) {
  final normalized = value.trim();
  if (normalized.length > maxSourceLinkLength) {
    throw const FormatException('El enlace admite hasta 2048 caracteres.');
  }
  if (RegExp(
    r'^https?://[^/?#]*@',
    caseSensitive: false,
  ).hasMatch(normalized)) {
    throw const FormatException('Introduce un enlace sin credenciales.');
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      !const {'https', 'http'}.contains(uri.scheme) ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.authority.contains('@') ||
      (uri.hasPort && (uri.port < 1 || uri.port > 65535)) ||
      uri.toString().length > maxSourceLinkLength ||
      uri.host.contains(RegExp(r'[%\s]'))) {
    throw const FormatException(
      'Introduce un enlace válido con https:// o http://.',
    );
  }
  return uri;
}
