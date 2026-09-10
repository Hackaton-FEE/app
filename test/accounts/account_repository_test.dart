import 'package:fee_app/features/accounts/data/demo_account_repository.dart';
import 'package:fee_app/features/accounts/domain/account_input.dart';
import 'package:fee_app/features/accounts/domain/account_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'the preview starts with one preview profile and no active session',
    () async {
      final accounts = await DemoAccountRepository().listAccounts();

      expect(accounts, hasLength(1));
      expect(accounts.map((account) => account.name), ['Cuenta personal']);
      expect(accounts.single.email == 'pedro.gomez@gmail.com', isTrue);
      expect(() => accounts.clear(), throwsUnsupportedError);
    },
  );

  test('adding a profile normalizes it and keeps existing list snapshots immutable', () async {
    final repository = DemoAccountRepository();
    final previous = await repository.listAccounts();

    final added = await repository.addAccount(
      name: '  Cuenta de prueba  ',
      email: '  PERFIL@EXAMPLE.INVALID  ',
    );

    expect(added.name, 'Cuenta de prueba');
    expect(added.email, 'perfil@example.invalid');
    expect(previous, hasLength(1));
    expect(await repository.listAccounts(), contains(added));
    expect(await repository.listAccounts(), hasLength(2));
  });

  test(
    'recreating the preview discards additions instead of persisting them',
    () async {
      final repository = DemoAccountRepository();
      await repository.addAccount(
        name: 'Temporal',
        email: 'temporal@example.invalid',
      );

      expect(await repository.listAccounts(), hasLength(2));
      expect(await DemoAccountRepository().listAccounts(), hasLength(1));
    },
  );

  test(
    'normalized duplicate emails cannot replace existing profiles',
    () async {
      final repository = DemoAccountRepository();
      await expectLater(
        repository.addAccount(
          name: 'Nombre distinto',
          email: ' PEDRO.GOMEZ@GMAIL.COM ',
        ),
        throwsA(
          isA<AccountRepositoryException>().having(
            (error) => error.reason,
            'reason',
            AccountRepositoryExceptionReason.duplicateEmail,
          ),
        ),
      );

      final accounts = await repository.listAccounts();
      expect(accounts, hasLength(1));
      expect(accounts.first.name, 'Cuenta personal');
    },
  );

  test('invalid profile inputs leave the preview unchanged', () async {
    final repository = DemoAccountRepository();
    for (final input in [
      (name: ' ', email: 'perfil@example.invalid'),
      (name: 'Nombre', email: 'sin-correo'),
      (name: 'Nombre\nOculto', email: 'perfil@example.invalid'),
      (name: 'Nombre', email: 'perfil..prueba@example.invalid'),
      (name: 'Nombre', email: 'perfil@-example.invalid'),
    ]) {
      await expectLater(
        repository.addAccount(name: input.name, email: input.email),
        throwsFormatException,
      );
    }
    expect(await repository.listAccounts(), hasLength(1));
  });

  test(
    'name limits count visible graphemes and independently bound huge clusters',
    () {
      final visibleName = List.filled(80, 'e\u0301').join();
      expect(AccountInput.validateName(visibleName), isNull);
      expect(AccountInput.validateName('$visibleName!'), isNotNull);
      expect(
        AccountInput.validateName('e${List.filled(3000, '\u0301').join()}'),
        isNotNull,
      );
      expect(
        AccountInput.validateEmail(
          '${List.filled(255, 'a').join()}@example.invalid',
        ),
        isNotNull,
      );
    },
  );
}
