import 'passkey_bridge_stub.dart'
    if (dart.library.js_interop) 'passkey_bridge_web.dart' as impl;
import 'passkey_models.dart';

/// Device passkey (WebAuthn) create / get. Web uses the browser authenticator;
/// tests inject a fake; other platforms report unsupported.
abstract class PasskeyBridge {
  const PasskeyBridge();

  static PasskeyBridge get instance => impl.createPasskeyBridge();

  bool get isSupported;

  Future<PasskeyRecord> register({
    required String email,
    required String userId,
    required String displayName,
    List<String> excludeCredentialIds = const [],
  });

  Future<PasskeyAssertion> authenticate({
    List<String> allowCredentialIds = const [],
  });
}
