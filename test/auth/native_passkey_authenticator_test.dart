import 'package:fee_app/features/auth/data/auth_api_client.dart';
import 'package:fee_app/features/auth/data/passkey_authenticator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeys/types.dart' as native;

const _registration = <String, dynamic>{
  'challenge': 'Y2hhbGxlbmdl',
  'rp': {'id': 'example.com', 'name': 'FEE'},
  'user': {'id': 'dXNlci1oYW5kbGU', 'name': 'Bóveda', 'displayName': 'Bóveda'},
  'pubKeyCredParams': [
    {'type': 'public-key', 'alg': -7},
  ],
  'authenticatorSelection': {
    'residentKey': 'required',
    'userVerification': 'required',
  },
  'attestation': 'none',
  'excludeCredentials': [
    {'type': 'public-key', 'id': 'ZXhjbHVkZWQ'},
  ],
};
const _authentication = <String, dynamic>{
  'challenge': 'Y2hhbGxlbmdl',
  'rpId': 'example.com',
  'userVerification': 'required',
};

class _Platform implements native.PasskeyAuthenticatorInterface {
  native.RegisterRequestType? registration;
  native.AuthenticateRequestType? authentication;
  Object? error;
  String signature = 'c2lnbmF0dXJl';
  int registrations = 0;

  @override
  Future<native.RegisterResponseType> register(
    native.RegisterRequestType request,
  ) async {
    registration = request;
    registrations++;
    if (error != null) throw error!;
    return const native.RegisterResponseType(
      id: 'bmF0aXZlLWlk',
      rawId: 'bmF0aXZlLWlk',
      clientDataJSON: 'Y2xpZW50LWRhdGE',
      attestationObject: 'YXR0ZXN0YXRpb24',
      transports: ['internal', 'hybrid'],
    );
  }

  @override
  Future<native.AuthenticateResponseType> authenticate(
    native.AuthenticateRequestType request,
  ) async {
    authentication = request;
    if (error != null) throw error!;
    return native.AuthenticateResponseType(
      id: 'bmF0aXZlLWlk',
      rawId: 'bmF0aXZlLWlk',
      clientDataJSON: 'Y2xpZW50LWRhdGE',
      authenticatorData: 'YXV0aGVudGljYXRvci1kYXRh',
      signature: signature,
      userHandle: 'dXNlci1oYW5kbGU',
    );
  }

  @override
  Future<void> signalUnknownCredential(
    native.SignalUnknownCredentialRequestType request,
  ) async {}

  @override
  Future<void> signalAllAcceptedCredentials(
    native.SignalAllAcceptedCredentialsRequestType request,
  ) async {}
}

class _FailingStorage extends FlutterSecureStorage {
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('sensitive-native-error');
  }
}

Matcher _code(String value) =>
    isA<AuthApiException>().having((error) => error.code, 'code', value);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Platform platform;
  late NativePasskeyAuthenticator authenticator;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    platform = _Platform();
    authenticator = NativePasskeyAuthenticator(platform: platform);
  });

  test(
    'registration preserves native attestation and server requirements',
    () async {
      final result = await authenticator.createCredential(_registration);

      expect(platform.registration!.challenge, 'Y2hhbGxlbmdl');
      expect(platform.registration!.relyingParty.id, 'example.com');
      expect(platform.registration!.authSelectionType!.residentKey, 'required');
      expect(
        platform.registration!.authSelectionType!.userVerification,
        'required',
      );
      expect(
        platform.registration!.excludeCredentials.single.transports,
        isEmpty,
      );
      expect(result['id'], 'bmF0aXZlLWlk');
      expect(result['response'], {
        'clientDataJSON': 'Y2xpZW50LWRhdGE',
        'attestationObject': 'YXR0ZXN0YXRpb24',
        'transports': ['internal', 'hybrid'],
      });
      expect(await authenticator.hasStoredCredential(), isTrue);
      final reopened = NativePasskeyAuthenticator(platform: platform);
      expect(await reopened.getStoredCredentialId(), 'bmF0aXZlLWlk');
      expect(_registration['excludeCredentials'], [
        {'type': 'public-key', 'id': 'ZXhjbHVkZWQ'},
      ]);
    },
  );

  test(
    'discoverable login requires native signature with no local ID',
    () async {
      expect(await authenticator.hasStoredCredential(), isFalse);

      final result = await authenticator.getCredential(_authentication);

      expect(platform.authentication!.allowCredentials, isNull);
      expect(
        platform.authentication!.preferImmediatelyAvailableCredentials,
        isFalse,
      );
      expect(platform.authentication!.userVerification, 'required');
      expect(result['response'], {
        'clientDataJSON': 'Y2xpZW50LWRhdGE',
        'authenticatorData': 'YXV0aGVudGljYXRvci1kYXRh',
        'signature': 'c2lnbmF0dXJl',
        'userHandle': 'dXNlci1oYW5kbGU',
      });
    },
  );

  test('legacy software ID is not reused and is preserved', () async {
    FlutterSecureStorage.setMockInitialValues({
      'fee.auth.v1.passkey_credential_id': 'old-id',
    });
    expect(await authenticator.hasStoredCredential(), isFalse);
    await authenticator.getCredential(_authentication);
    expect(platform.authentication!.allowCredentials, isNull);
    expect(
      await const FlutterSecureStorage().read(
        key: 'fee.auth.v1.passkey_credential_id',
      ),
      'old-id',
    );
  });

  test(
    'cancellation has no fallback registration or stored credential',
    () async {
      platform.error = native.PasskeyAuthCancelledException();
      await expectLater(
        authenticator.getCredential(_authentication),
        throwsA(_code('passkey_cancelled')),
      );
      expect(platform.registrations, 0);
      expect(await authenticator.hasStoredCredential(), isFalse);
    },
  );

  test('association failure does not expose platform error details', () async {
    platform.error = native.DomainNotAssociatedException('private-device-data');
    try {
      await authenticator.createCredential(_registration);
      fail('must fail');
    } on AuthApiException catch (error) {
      expect(error.code, 'passkey_domain_unavailable');
      expect(error.toString(), isNot(contains('private-device-data')));
    }
  });

  test('missing native signature cannot become success', () async {
    platform.signature = '';
    await expectLater(
      authenticator.getCredential(_authentication),
      throwsA(_code('invalid_passkey_response')),
    );
    expect(await authenticator.hasStoredCredential(), isFalse);
  });

  test(
    'storage failure prevents successful completion and memory fallback',
    () async {
      authenticator = NativePasskeyAuthenticator(
        platform: platform,
        storage: _FailingStorage(),
      );
      await expectLater(
        authenticator.createCredential(_registration),
        throwsA(_code('passkey_storage_error')),
      );
      expect(await authenticator.hasStoredCredential(), isFalse);
    },
  );

  test('clearing the local hint does not erase system passkeys', () async {
    await authenticator.createCredential(_registration);
    await authenticator.clearStoredCredential();
    expect(await authenticator.hasStoredCredential(), isFalse);
    await authenticator.getCredential(_authentication);
    expect(await authenticator.hasStoredCredential(), isTrue);
  });
}
