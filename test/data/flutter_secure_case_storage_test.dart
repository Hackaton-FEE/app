import 'package:fee_app/features/cases/data/flutter_secure_case_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> values;
  late List<MethodCall> calls;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    values = {};
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          final arguments = call.arguments as Map;
          switch (call.method) {
            case 'write':
              values[arguments['key'] as String] = arguments['value'] as String;
              return null;
            case 'readAll':
              return Map.of(values);
            case 'delete':
              values.remove(arguments['key']);
              return null;
            default:
              throw StateError('Unexpected storage operation');
          }
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'prefix isolates records and deleting one leaves other namespaces intact',
    () async {
      values['unrelated.key'] = 'other data';
      final storage = FlutterSecureCaseStorage(prefix: 'test.case.');
      await storage.write('first', '{"id":"first"}');
      await storage.write('second', '{"id":"second"}');
      expect(values.keys, [
        'unrelated.key',
        'test.case.first',
        'test.case.second',
      ]);
      expect(await storage.readAll(), {
        'first': '{"id":"first"}',
        'second': '{"id":"second"}',
      });
      await storage.delete('first');
      expect(values.keys, ['unrelated.key', 'test.case.second']);
      expect(calls.map((call) => call.method), isNot(contains('deleteAll')));
    },
  );

  test(
    'Android explicitly disables destructive recovery and isolates storage',
    () async {
      final storage = FlutterSecureCaseStorage();
      await storage.write('one', '{}');
      final options = (calls.single.arguments as Map)['options'] as Map;
      expect(options['resetOnError'], 'false');
      expect(options['storageNamespace'], 'fee_cases');
    },
  );

  test(
    'iOS uses device-local keychain without cloud synchronization',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await FlutterSecureCaseStorage().readAll();
      final options = (calls.single.arguments as Map)['options'] as Map;
      expect(options['accountName'], 'org.hackatonfee.feeApp.cases');
      expect(options['accessibility'], 'unlocked_this_device');
      expect(options['synchronizable'], 'false');
    },
  );

  test(
    'injected storage namespace is respected for integration isolation',
    () async {
      final storage = FlutterSecureCaseStorage(
        prefix: 'test.',
        storage: const FlutterSecureStorage(
          aOptions: AndroidOptions(
            resetOnError: false,
            storageNamespace: 'isolated_test',
          ),
        ),
      );
      await storage.write('one', '{}');
      await storage.readAll();
      await storage.delete('one');
      for (final call in calls) {
        final options = (call.arguments as Map)['options'] as Map;
        expect(options['storageNamespace'], 'isolated_test');
      }
    },
  );
}
