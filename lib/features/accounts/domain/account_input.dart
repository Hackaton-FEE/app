import 'dart:convert';

import 'package:characters/characters.dart';

/// Shared validation for the local profile form and repository.
class AccountInput {
  factory AccountInput({required String name, required String email}) {
    final nameError = validateName(name);
    final emailError = validateEmail(email);
    if (nameError != null || emailError != null) {
      throw FormatException(nameError ?? emailError!);
    }
    return AccountInput._(name.trim(), email.trim().toLowerCase());
  }

  const AccountInput._(this.name, this.email);

  static const maxNameLength = 80;
  static const maxEmailLength = 254;
  static const maxEncodedNameBytes = 4 * 1024;

  static final _controlCharacters = RegExp(r'[\x00-\x1f\x7f]');
  static final _emailPattern = RegExp(
    r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$",
  );

  final String name;
  final String email;

  static String? validateName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.characters.length > maxNameLength) {
      return 'Escribe un nombre de 1 a 80 caracteres.';
    }
    if (_controlCharacters.hasMatch(normalized)) {
      return 'Escribe el nombre en una sola línea, sin caracteres de control.';
    }
    // A single visible grapheme can contain arbitrarily many combining marks.
    if (utf8.encode(jsonEncode(normalized)).length > maxEncodedNameBytes) {
      return 'El nombre es demasiado grande. Usa uno más corto.';
    }
    return null;
  }

  static String? validateEmail(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || normalized.length > maxEmailLength) {
      return 'Escribe un correo válido de hasta 254 caracteres.';
    }
    if (!_emailPattern.hasMatch(normalized)) {
      return 'Escribe un correo con el formato nombre@ejemplo.com.';
    }
    final parts = normalized.split('@');
    if (parts.first.length > 64 ||
        parts.first.startsWith('.') ||
        parts.first.endsWith('.') ||
        parts.first.contains('..') ||
        parts.last.split('.').any((label) => label.length > 63)) {
      return 'Revisa el formato del correo electrónico.';
    }
    return null;
  }
}
