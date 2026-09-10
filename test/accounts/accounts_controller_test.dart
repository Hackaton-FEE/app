import 'dart:async';

import '../support/demo_account_repository.dart';

import 'package:fee_app/features/accounts/domain/account_repository.dart';
import 'package:fee_app/features/accounts/domain/local_account.dart';
import 'package:fee_app/features/accounts/presentation/accounts_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'launch loads the account selector and choosing a known account enters it',
    () async {
      final controller = AccountsController(DemoAccountRepository());
      addTearDown(controller.dispose);
      expect(controller.isLoading, isTrue);
      expect(controller.activeAccount, isNull);

      await controller.load();
      expect(controller.isLoading, isFalse);
      expect(controller.accounts, hasLength(1));
      expect(controller.activeAccount, isNull);
      expect(controller.selectAccount(controller.accounts.first), isTrue);
      expect(controller.activeAccount, same(controller.accounts.first));

      controller.signOut();
      expect(controller.activeAccount, isNull);
      expect(controller.accounts, hasLength(1));
    },
  );

  test('recreating a controller requires another selection', () async {
    final repository = DemoAccountRepository();
    final first = AccountsController(repository);
    addTearDown(first.dispose);
    await first.load();
    first.selectAccount(first.accounts.first);

    final reopened = AccountsController(repository);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.accounts, hasLength(1));
    expect(reopened.activeAccount, isNull);
  });

  test(
    'selection uses the repository profile and rejects unknown identities',
    () async {
      final controller = AccountsController(DemoAccountRepository());
      addTearDown(controller.dispose);
      await controller.load();

      final canonical = controller.accounts.first;
      expect(
        controller.selectAccount(
          LocalAccount(
            id: canonical.id,
            name: 'Otro nombre',
            email: 'otro@example.invalid',
          ),
        ),
        isTrue,
      );
      expect(controller.activeAccount, same(canonical));
      expect(
        controller.selectAccount(
          const LocalAccount(
            id: 'unknown',
            name: 'Desconocida',
            email: 'desconocida@example.invalid',
          ),
        ),
        isFalse,
      );
      expect(controller.activeAccount, same(canonical));
      expect(controller.error, isNotNull);
    },
  );

  test('an addition activates only after the repository completes and blocks overlapping actions', () async {
    final repository = _ControlledRepository()
      ..addGate = Completer<LocalAccount>();
    final controller = AccountsController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    controller.selectAccount(controller.accounts.first);
    final original = controller.activeAccount;

    final adding = controller.addAccount(
      name: 'Nueva cuenta',
      email: 'nueva@example.invalid',
    );
    expect(controller.isSaving, isTrue);
    expect(controller.activeAccount, same(original));
    expect(controller.accounts, hasLength(1));
    expect(controller.selectAccount(controller.accounts.last), isFalse);
    controller.signOut();
    expect(controller.activeAccount, same(original));
    expect(
      await controller.addAccount(name: 'Otra', email: 'otra@example.invalid'),
      isFalse,
    );

    const added = LocalAccount(
      id: 'added',
      name: 'Nueva cuenta',
      email: 'nueva@example.invalid',
    );
    repository.addGate!.complete(added);
    expect(await adding, isTrue);
    expect(controller.isSaving, isFalse);
    expect(controller.activeAccount, same(added));
    expect(controller.accounts, hasLength(2));
  });

  test('a failed addition keeps the prior session and excludes private exception contents', () async {
    final repository = _ControlledRepository()
      ..addError = StateError('privado@example.invalid');
    final controller = AccountsController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    controller.selectAccount(controller.accounts.first);
    final original = controller.activeAccount;

    expect(
      await controller.addAccount(
        name: 'Nueva',
        email: 'nueva@example.invalid',
      ),
      isFalse,
    );
    expect(controller.isSaving, isFalse);
    expect(controller.activeAccount, same(original));
    expect(controller.accounts, hasLength(1));
    expect(controller.actionError, isNotNull);
    expect(controller.error, isNot(contains('privado@example.invalid')));
  });

  test(
    'a failed reload preserves loaded profiles and retry restores selection',
    () async {
      final repository = _ControlledRepository();
      final controller = AccountsController(repository);
      addTearDown(controller.dispose);
      await controller.load();
      repository.loadError = const AccountRepositoryException(
        AccountRepositoryExceptionReason.unavailable,
      );

      await controller.load();
      expect(controller.accounts, hasLength(1));
      expect(controller.loadError, isNotNull);
      expect(controller.selectAccount(controller.accounts.first), isFalse);
      expect(
        await controller.addAccount(
          name: 'Nueva',
          email: 'nueva@example.invalid',
        ),
        isFalse,
      );

      repository.loadError = null;
      await controller.load();
      expect(controller.error, isNull);
      expect(controller.selectAccount(controller.accounts.last), isTrue);
    },
  );

  test('disposing while a repository action finishes emits no further notifications', () async {
    final repository = _ControlledRepository()
      ..addGate = Completer<LocalAccount>();
    final controller = AccountsController(repository);
    await controller.load();
    var notifications = 0;
    controller.addListener(() => notifications++);
    final adding = controller.addAccount(
      name: 'Nueva',
      email: 'nueva@example.invalid',
    );
    expect(notifications, 1);
    controller.dispose();
    repository.addGate!.complete(
      const LocalAccount(
        id: 'added',
        name: 'Nueva',
        email: 'nueva@example.invalid',
      ),
    );
    expect(await adding, isFalse);
    expect(notifications, 1);
  });
}

class _ControlledRepository implements AccountRepository {
  final DemoAccountRepository delegate = DemoAccountRepository();
  Completer<LocalAccount>? addGate;
  Object? addError;
  Object? loadError;

  @override
  Future<List<LocalAccount>> listAccounts() async {
    if (loadError case final error?) throw error;
    return delegate.listAccounts();
  }

  @override
  Future<LocalAccount> addAccount({
    required String name,
    required String email,
  }) async {
    if (addError case final error?) throw error;
    if (addGate case final gate?) return gate.future;
    return delegate.addAccount(name: name, email: email);
  }
}
