import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'passkey_bridge.dart';
import 'passkey_models.dart';

PasskeyBridge createPasskeyBridge() => const WebPasskeyBridge();

class WebPasskeyBridge extends PasskeyBridge {
  const WebPasskeyBridge();

  @override
  bool get isSupported {
    try {
      web.window.navigator.credentials;
      return true;
    } catch (_) {
      return false;
    }
  }

  String get _rpId {
    final host = web.window.location.hostname;
    if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
      return host.isEmpty ? 'localhost' : host;
    }
    return host;
  }

  @override
  Future<PasskeyRecord> register({
    required String email,
    required String userId,
    required String displayName,
    List<String> excludeCredentialIds = const [],
  }) async {
    if (!isSupported) {
      throw PasskeyException('Passkeys are not available in this browser.');
    }
    try {
      final exclude = excludeCredentialIds
          .where((id) => id.isNotEmpty)
          .map(
            (id) => web.PublicKeyCredentialDescriptor(
              type: 'public-key',
              id: _bytes(id).toJS,
            ),
          )
          .toList();
      final options = web.CredentialCreationOptions(
        publicKey: web.PublicKeyCredentialCreationOptions(
          rp: web.PublicKeyCredentialRpEntity(name: 'Hubsom', id: _rpId),
          user: web.PublicKeyCredentialUserEntity(
            name: email,
            id: Uint8List.fromList(utf8.encode(email)).toJS,
            displayName: displayName.isEmpty ? email : displayName,
          ),
          challenge: _challenge().toJS,
          pubKeyCredParams: <web.PublicKeyCredentialParameters>[
            web.PublicKeyCredentialParameters(type: 'public-key', alg: -7),
            web.PublicKeyCredentialParameters(type: 'public-key', alg: -257),
          ].toJS,
          timeout: 60000,
          excludeCredentials: exclude.toJS,
          authenticatorSelection: web.AuthenticatorSelectionCriteria(
            authenticatorAttachment: 'platform',
            residentKey: 'preferred',
            userVerification: 'preferred',
          ),
          attestation: 'none',
        ),
      );
      final cred = await web.window.navigator.credentials.create(options).toDart;
      if (cred == null || cred.id.isEmpty) {
        throw PasskeyException('Passkey was cancelled');
      }
      final pk = cred as web.PublicKeyCredential;
      return PasskeyRecord(
        id: cred.id,
        email: email,
        userId: userId,
        label: _labelFor(pk.authenticatorAttachment),
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );
    } on PasskeyException {
      rethrow;
    } catch (e) {
      throw PasskeyException(_humanize(e));
    }
  }

  @override
  Future<PasskeyAssertion> authenticate({
    List<String> allowCredentialIds = const [],
  }) async {
    if (!isSupported) {
      throw PasskeyException('Passkeys are not available in this browser.');
    }
    try {
      final allow = allowCredentialIds
          .where((id) => id.isNotEmpty)
          .map(
            (id) => web.PublicKeyCredentialDescriptor(
              type: 'public-key',
              id: _bytes(id).toJS,
            ),
          )
          .toList();
      final options = web.CredentialRequestOptions(
        mediation: 'required',
        publicKey: web.PublicKeyCredentialRequestOptions(
          challenge: _challenge().toJS,
          timeout: 60000,
          rpId: _rpId,
          userVerification: 'preferred',
          allowCredentials: allow.toJS,
        ),
      );
      final cred = await web.window.navigator.credentials.get(options).toDart;
      if (cred == null || cred.id.isEmpty) {
        throw PasskeyException('Passkey was cancelled');
      }
      String? handle;
      try {
        final pk = cred as web.PublicKeyCredential;
        final response = pk.response as web.AuthenticatorAssertionResponse;
        final raw = response.userHandle;
        if (raw != null) {
          handle = utf8.decode(raw.toDart.asUint8List());
        }
      } catch (_) {}
      return PasskeyAssertion(credentialId: cred.id, userHandle: handle);
    } on PasskeyException {
      rethrow;
    } catch (e) {
      throw PasskeyException(_humanize(e));
    }
  }

  static String _labelFor(String? attachment) {
    switch (attachment) {
      case 'platform':
        return 'This device';
      case 'cross-platform':
        return 'Security key';
      default:
        return 'Passkey';
    }
  }

  static Uint8List _challenge() {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => r.nextInt(256)));
  }

  static Uint8List _bytes(String b64url) {
    var t = b64url.replaceAll('-', '+').replaceAll('_', '/');
    switch (t.length % 4) {
      case 2:
        t += '==';
      case 3:
        t += '=';
    }
    return Uint8List.fromList(base64Decode(t));
  }

  static String _humanize(Object error) {
    final msg = '$error';
    if (msg.contains('NotAllowed') ||
        msg.contains('Abort') ||
        msg.contains('NotAllowedError')) {
      return 'Passkey was cancelled';
    }
    if (msg.contains('InvalidState') || msg.contains('already')) {
      return 'This passkey is already saved on Hubsom.';
    }
    return 'Could not use a passkey on this device';
  }
}
