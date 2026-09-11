import 'package:fee_app/features/footprint/domain/scan_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScanTarget', () {
    test('parses usernames correctly', () {
      final t1 = ScanTarget.parse('pedro');
      expect(t1.type, 'username');
      expect(t1.identifier, 'pedro');

      final t2 = ScanTarget.parse('pedro_dev');
      expect(t2.type, 'username');
      expect(t2.identifier, 'pedro_dev');

      final t3 = ScanTarget.parse('user-123.io');
      expect(t3.type, 'username');
      expect(t3.identifier, 'user-123.io');
    });

    test('parses full names with spaces and accents correctly', () {
      final t1 = ScanTarget.parse('Pedro Ibarra');
      expect(t1.type, 'name');
      expect(t1.identifier, 'Pedro Ibarra');

      final t2 = ScanTarget.parse('María José Gómez');
      expect(t2.type, 'name');
      expect(t2.identifier, 'María José Gómez');

      final t3 = ScanTarget.parse("Jean-Luc D'Artagnan");
      expect(t3.type, 'name');
      expect(t3.identifier, "Jean-Luc D'Artagnan");
    });

    test('parses emails correctly', () {
      final t1 = ScanTarget.parse('pedro@example.com');
      expect(t1.type, 'email');
      expect(t1.identifier, 'pedro@example.com');

      final t2 = ScanTarget.parse('user.name+tag@sub.domain.org');
      expect(t2.type, 'email');
      expect(t2.identifier, 'user.name+tag@sub.domain.org');
    });

    test('parses phone numbers with normalization', () {
      final t1 = ScanTarget.parse('+52 (55) 1234-5678');
      expect(t1.type, 'phone');
      expect(t1.identifier, '+525512345678');

      final t2 = ScanTarget.parse('+1 800 555 0199');
      expect(t2.type, 'phone');
      expect(t2.identifier, '+18005550199');
    });

    test('rejects invalid inputs with descriptive FormatException', () {
      expect(() => ScanTarget.parse(''), throwsFormatException);
      expect(() => ScanTarget.parse('a'), throwsFormatException);
      expect(() => ScanTarget.parse('notanemail@'), throwsFormatException);
      expect(() => ScanTarget.parse('@missinguser.com'), throwsFormatException);
      expect(() => ScanTarget.parse('+123'), throwsFormatException);
      expect(() => ScanTarget.parse('+abc-def'), throwsFormatException);
      expect(() => ScanTarget.parse('invalid!@#\$%^&*'), throwsFormatException);
    });
  });
}
