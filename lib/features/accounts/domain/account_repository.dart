import 'local_account.dart';

enum AccountRepositoryExceptionReason { unavailable, duplicateEmail }

/// Never carries internal messages or profile details.
class AccountRepositoryException implements Exception {
  const AccountRepositoryException(this.reason);

  final AccountRepositoryExceptionReason reason;

  @override
  String toString() => 'AccountRepositoryException(${reason.name})';
}

abstract interface class AccountRepository {
  Future<List<LocalAccount>> listAccounts();
  Future<LocalAccount> addAccount({
    required String name,
    required String email,
  });
}
