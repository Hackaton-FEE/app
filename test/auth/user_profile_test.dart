import 'package:fee_app/features/auth/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // MeResponse from server/src/fee_server/domain/auth/schemas.py.
  final response = <String, dynamic>{
    'id': 'account-test',
    'label': 'Etiqueta de cuenta',
    'created_at': '2026-09-10T12:34:56.123456Z',
    'credentials_count': 2,
  };

  test(
    'uses server facts and never derives a scan identifier from the label',
    () {
      final profile = UserProfile.fromJson(response);
      final account = profile.toLocalAccount();
      expect(
        profile.createdAt,
        DateTime.utc(2026, 9, 10, 12, 34, 56, 123, 456),
      );
      expect(profile.credentialsCount, 2);
      expect(profile.label, 'Etiqueta de cuenta');
      expect(profile.email, isEmpty);
      expect(account.email, isEmpty);
      expect(account.name, 'Etiqueta de cuenta');
    },
  );

  test(
    'empty server label is a UI placeholder, never a made-up identifier',
    () {
      final account = UserProfile.fromJson({...response, 'label': ''})
          .toLocalAccount();
      expect(account.name, 'Usuario');
      expect(account.email, isEmpty);
    },
  );

  for (final field in response.keys) {
    test('missing $field is rejected rather than defaulted', () {
      final incomplete = Map<String, dynamic>.from(response)..remove(field);
      expect(() => UserProfile.fromJson(incomplete), throwsFormatException);
    });
  }

  for (final invalid in [
    {'id': ''},
    {'label': null},
    {'created_at': 'not a date'},
    {'created_at': '2026-02-30T12:00:00Z'},
    {'created_at': '2026-09-10T25:00:00Z'},
    {'created_at': '2026-09-10T12:00:00+05:99'},
    {'credentials_count': -1},
    {'credentials_count': 1.5},
    {'is_active': 'true'},
    {'email': 123},
  ]) {
    test('rejects invalid profile fields $invalid without echoing them', () {
      expect(
        () => UserProfile.fromJson({...response, ...invalid}),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'safe message',
            'El perfil del servidor no es válido.',
          ),
        ),
      );
    });
  }

  test('retains explicit email and inactive flag when provided', () {
    final profile = UserProfile.fromJson({
      ...response,
      'email': 'fixture@example.invalid',
      'is_active': false,
    });
    expect(profile.toLocalAccount().email, 'fixture@example.invalid');
    expect(profile.toLocalAccount().isActive, isFalse);
  });
}
