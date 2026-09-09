import 'dart:convert';

import 'package:characters/characters.dart';

import 'privacy_case.dart';
import 'source_link.dart' as source_link;

/// Validated metadata, with visible-character limits matching Flutter forms.
///
/// A separate encoded-size bound also limits unusually large grapheme clusters
/// and JSON escape expansion, leaving room for the record's identity and dates.
class CaseInput {
  factory CaseInput({
    required String title,
    required String sourceUrl,
    required CaseCategory category,
    String notes = '',
  }) {
    final normalizedTitle = title.trim();
    final normalizedNotes = notes.trim();
    if (normalizedTitle.isEmpty ||
        normalizedTitle.characters.length > maxTitleLength) {
      throw const FormatException('Escribe un título de 1 a 80 caracteres.');
    }
    if (normalizedNotes.characters.length > maxNotesLength) {
      throw const FormatException('Las notas admiten hasta 2000 caracteres.');
    }
    final parsedSource = source_link.parseSourceLink(sourceUrl);
    final encodedMetadata = jsonEncode({
      'title': normalizedTitle,
      'sourceUrl': parsedSource.toString(),
      'category': category.name,
      'notes': normalizedNotes,
    });
    if (utf8.encode(encodedMetadata).length > maxEncodedMetadataBytes) {
      throw const FormatException(
        'El texto es demasiado grande para guardarlo en el dispositivo.',
      );
    }
    return CaseInput._(
      title: normalizedTitle,
      sourceUrl: parsedSource,
      category: category,
      notes: normalizedNotes,
    );
  }

  const CaseInput._({
    required this.title,
    required this.sourceUrl,
    required this.category,
    required this.notes,
  });

  static const maxTitleLength = 80;
  static const maxNotesLength = 2000;
  static const maxSourceLinkLength = source_link.maxSourceLinkLength;
  static const maxEncodedMetadataBytes = 24 * 1024;

  final String title;
  final Uri sourceUrl;
  final CaseCategory category;
  final String notes;
}
