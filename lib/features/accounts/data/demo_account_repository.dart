import 'package:uuid/uuid.dart';

import '../domain/account_input.dart';
import '../domain/account_repository.dart';
import '../domain/local_account.dart';

/// Preview data lives only in memory, with no authentication or remote service.
class DemoAccountRepository implements AccountRepository {
  DemoAccountRepository({List<LocalAccount>? initialAccounts})
    : _accounts = [...initialAccounts ?? exampleAccounts];

  static const exampleAccounts = [
    LocalAccount(
      id: 'demo-personal',
      name: 'Cuenta personal',
      email: 'pedro.demo@gmail.com',
    ),
  ];

  final List<LocalAccount> _accounts;

  @override
  Future<List<LocalAccount>> listAccounts() async =>
      List.unmodifiable(_accounts);

  @override
  Future<LocalAccount> addAccount({
    required String name,
    required String email,
  }) async {
    final input = AccountInput(name: name, email: email);
    if (_accounts.any((account) => account.email == input.email)) {
      throw const AccountRepositoryException(
        AccountRepositoryExceptionReason.duplicateEmail,
      );
    }
    final account = LocalAccount(
      id: const Uuid().v4(),
      name: input.name,
      email: input.email,
    );
    _accounts.add(account);
    return account;
  }
}
