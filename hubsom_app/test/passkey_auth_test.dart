import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/auth/passkey_bridge.dart';
import 'package:hubsom_app/core/auth/passkey_models.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/repositories/auth_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/features/authentication/sign_in_page.dart';
import 'package:hubsom_app/features/settings/settings_page.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePasskeyBridge extends PasskeyBridge {
  FakePasskeyBridge({this.supported = true});

  bool supported;
  final records = <PasskeyRecord>[];
  bool cancelNext = false;

  @override
  bool get isSupported => supported;

  @override
  Future<PasskeyRecord> register({
    required String email,
    required String userId,
    required String displayName,
    List<String> excludeCredentialIds = const [],
  }) async {
    if (!supported) {
      throw PasskeyException('Passkeys are not available in this browser.');
    }
    if (cancelNext) {
      cancelNext = false;
      throw PasskeyException('Passkey was cancelled');
    }
    final record = PasskeyRecord(
      id: 'pk-${records.length + 1}',
      email: email,
      userId: userId,
      label: 'This device',
      createdAt: '2026-09-05T12:00:00.000Z',
    );
    records.add(record);
    return record;
  }

  @override
  Future<PasskeyAssertion> authenticate({
    List<String> allowCredentialIds = const [],
  }) async {
    if (records.isEmpty) {
      throw PasskeyException('No passkey found');
    }
    final record = records.last;
    return PasskeyAssertion(
      credentialId: record.id,
      userHandle: record.email,
    );
  }
}

String _hash(String password, String salt) {
  return sha256.convert(utf8.encode('$salt::$password::hubsom')).toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-passkey');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  setUp(() {
    CloudStore.useNetwork = false;
  });

  test('signed-in user can add a passkey and sign in with it', () async {
    const salt = 'test-salt';
    const password = 'password1';
    final user = HubsomUser(
      id: 'local-pk',
      email: 'ama@hubsom.test',
      name: 'Ama',
      role: 'buyer',
    );
    await LocalStore.saveCredentialVault({
      'ama@hubsom.test': {
        'salt': salt,
        'hash': _hash(password, salt),
        'userJson': user.toJson(),
      },
    });
    final fake = FakePasskeyBridge();
    final repo = AuthRepository(ApiClient(), passkeys: fake);

    await repo.signIn(email: 'ama@hubsom.test', password: password);
    final saved = await repo.registerPasskey();
    expect(saved.label, 'This device');
    expect(repo.listPasskeys(), hasLength(1));

    await repo.signOut();
    expect(repo.currentUser(), isNull);

    final viaPasskey = await repo.signInWithPasskey();
    expect(viaPasskey.email, 'ama@hubsom.test');
    expect(viaPasskey.name, 'Ama');
  });

  test('cancelled passkey does not sign the user in', () async {
    const salt = 'test-salt';
    const password = 'password1';
    final user = HubsomUser(
      id: 'local-pk-2',
      email: 'kojo@hubsom.test',
      name: 'Kojo',
      role: 'buyer',
    );
    await LocalStore.saveCredentialVault({
      'kojo@hubsom.test': {
        'salt': salt,
        'hash': _hash(password, salt),
        'userJson': user.toJson(),
      },
    });
    final fake = FakePasskeyBridge()..cancelNext = true;
    final repo = AuthRepository(ApiClient(), passkeys: fake);
    await repo.signIn(email: 'kojo@hubsom.test', password: password);

    expect(
      () => repo.registerPasskey(),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Passkey was cancelled',
        ),
      ),
    );
    expect(repo.listPasskeys(), isEmpty);
  });

  testWidgets('sign-in shows passkey when the device supports it', (tester) async {
    final fake = FakePasskeyBridge();
    final router = GoRouter(
      initialLocation: '/auth/sign-in',
      routes: [
        GoRoute(
          path: '/auth/sign-in',
          builder: (_, __) => const SignInPage(),
        ),
        GoRoute(path: '/account', builder: (_, __) => const Scaffold(body: Text('Account'))),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          passkeyBridgeProvider.overrideWithValue(fake),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(find.text('Sign in with passkey'), findsOneWidget);
    expect(find.text('or use your password'), findsOneWidget);
  });

  testWidgets('settings lists passkeys', (tester) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        GoRoute(
          path: '/settings/passkeys',
          builder: (_, __) => const Scaffold(body: Text('Passkeys screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();

    expect(find.text('Passkeys'), findsOneWidget);
    await tester.tap(find.text('Passkeys'));
    await tester.pumpAndSettle();
    expect(find.text('Passkeys screen'), findsOneWidget);
  });
}
