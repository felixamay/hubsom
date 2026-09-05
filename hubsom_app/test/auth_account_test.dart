import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/auth_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-auth');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  test('sign-in without an account asks to create one', () async {
    final repo = AuthRepository(ApiClient());
    expect(
      () => repo.signIn(email: 'nobody@hubsom.test', password: 'password1'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('No account found'),
        ),
      ),
    );
  });

  test('same-browser vault can still sign in when the network is off', () async {
    const salt = 'test-salt';
    const password = 'password1';
    final user = HubsomUser(
      id: 'local-2',
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

    final signedIn = await AuthRepository(ApiClient()).signIn(
      email: 'kojo@hubsom.test',
      password: password,
    );
    expect(signedIn.email, 'kojo@hubsom.test');
    expect(signedIn.name, 'Kojo');

    expect(
      () => AuthRepository(ApiClient()).signIn(
        email: 'kojo@hubsom.test',
        password: 'wrongpass',
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('signed-in user can change password and sign in with the new one', () async {
    const salt = 'test-salt';
    const current = 'password1';
    const next = 'password2';
    final user = HubsomUser(
      id: 'local-3',
      email: 'ama@hubsom.test',
      name: 'Ama',
      role: 'buyer',
    );
    await LocalStore.saveCredentialVault({
      'ama@hubsom.test': {
        'salt': salt,
        'hash': _hash(current, salt),
        'userJson': user.toJson(),
      },
    });
    final repo = AuthRepository(ApiClient());
    await repo.signIn(email: 'ama@hubsom.test', password: current);

    expect(
      () => repo.changePassword(
        currentPassword: 'wrongpass',
        newPassword: next,
      ),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Current password is incorrect',
        ),
      ),
    );
    expect(
      () => repo.changePassword(
        currentPassword: current,
        newPassword: current,
      ),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('different'),
        ),
      ),
    );

    await repo.changePassword(currentPassword: current, newPassword: next);
    await repo.signOut();

    expect(
      () => repo.signIn(email: 'ama@hubsom.test', password: current),
      throwsA(isA<AuthException>()),
    );
    final signedIn = await repo.signIn(
      email: 'ama@hubsom.test',
      password: next,
    );
    expect(signedIn.email, 'ama@hubsom.test');
  });
}

/// Same formula as AuthRepository: sha256('$salt::$password::hubsom').
String _hash(String password, String salt) {
  return sha256.convert(utf8.encode('$salt::$password::hubsom')).toString();
}
