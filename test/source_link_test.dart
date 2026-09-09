import 'package:fee_app/features/cases/domain/source_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts a web link and preserves its path and query', () {
    final link = parseSourceLink('  https://example.com/post?id=1  ');
    expect(link.toString(), 'https://example.com/post?id=1');
  });

  test('rejects missing hosts, non-web schemes, and embedded credentials', () {
    for (final value in [
      '',
      'example.com/post',
      'https://',
      'file:///private/photo.jpg',
      'javascript:alert(1)',
      'https://name:password@example.com',
      'https://invalid host/post',
      'https://invalid%20host/post',
    ]) {
      expect(
        () => parseSourceLink(value),
        throwsFormatException,
        reason: value,
      );
    }
  });
}
