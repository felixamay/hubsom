import 'passkey_bridge.dart';
import 'passkey_models.dart';

PasskeyBridge createPasskeyBridge() => const StubPasskeyBridge();

class StubPasskeyBridge extends PasskeyBridge {
  const StubPasskeyBridge();

  @override
  bool get isSupported => false;

  @override
  Future<PasskeyRecord> register({
    required String email,
    required String userId,
    required String displayName,
    List<String> excludeCredentialIds = const [],
  }) async {
    throw PasskeyException(
      'Passkeys work in the Hubsom web app on a phone or computer that supports Face ID, Touch ID, or Windows Hello.',
    );
  }

  @override
  Future<PasskeyAssertion> authenticate({
    List<String> allowCredentialIds = const [],
  }) async {
    throw PasskeyException(
      'Passkeys work in the Hubsom web app on a supported device.',
    );
  }
}
