import 'package:fee_app/features/auth/data/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingStorage extends FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw StateError('unreadable');

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw StateError('not-deleted');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('read failure is an error and is not an empty session', () async {
    final storage = SecureTokenStorage(storage: _FailingStorage());
    await expectLater(storage.readRefreshToken(), throwsStateError);
  });

  test('failed persistent deletion does not confirm logout', () async {
    final storage = SecureTokenStorage(storage: _FailingStorage());
    storage.accessToken = 'current-access';
    await expectLater(storage.clearAll(), throwsStateError);
    expect(storage.accessToken, 'current-access');
  });

  test(
    'refresh persists across repositories and successful clear removes it',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final storage = SecureTokenStorage();
      await storage.saveRefreshToken('persisted-refresh');
      final reopened = SecureTokenStorage();
      expect(await reopened.readRefreshToken(), 'persisted-refresh');
      reopened.accessToken = 'current-access';
      await reopened.clearAll();
      expect(await reopened.readRefreshToken(), isNull);
      expect(reopened.accessToken, isNull);
    },
  );
}
