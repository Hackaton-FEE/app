import 'package:fee_app/features/accounts/data/flutter_secure_identity_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  test(
    'Android read failure is reported with destructive recovery disabled',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            throw PlatformException(code: 'storage_unavailable');
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await expectLater(
        FlutterSecureIdentityStorage().read('test-account'),
        throwsA(isA<PlatformException>()),
      );
      expect(calls.map((call) => call.method), ['read']);
      final options = (calls.single.arguments as Map)['options'] as Map;
      expect(options['resetOnError'], 'false');
      expect(options['storageNamespace'], 'fee_identity');
    },
  );
}
