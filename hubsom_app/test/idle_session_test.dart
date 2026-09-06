import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/auth/idle_session.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/repositories/auth_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = HubsomUser(
  id: 'local-idle',
  email: 'idle@hubsom.test',
  name: 'Idle User',
  role: 'buyer',
);

Future<void> _persistSession({required DateTime lastActivity}) async {
  await LocalStore.setSessionToken('hubsom.idle-token');
  await LocalStore.setUserJson(jsonEncode(_user.toJson()));
  await LocalStore.setLastActivityMs(lastActivity.millisecondsSinceEpoch);
}

String _hash(String password, String salt) {
  return sha256.convert(utf8.encode('$salt::$password::hubsom')).toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-idle');
    Hive.init(dir.path);
    await LocalStore.init();
    IdleSession.resetForTest();
  });

  tearDown(IdleSession.resetForTest);

  test('session stays valid for 29 minutes then expires at 30', () async {
    var now = DateTime.utc(2026, 9, 6, 12);
    IdleSession.clock = () => now;
    await _persistSession(lastActivity: now);

    now = now.add(const Duration(minutes: 29));
    expect(IdleSession.isExpired(), isFalse);
    expect(AuthRepository(ApiClient()).currentUser()?.email, _user.email);

    now = now.add(const Duration(minutes: 1));
    expect(IdleSession.isExpired(), isTrue);
    expect(await IdleSession.expireIfIdle(), isTrue);
    expect(AuthRepository(ApiClient()).currentUser(), isNull);
    expect(LocalStore.sessionToken, isNull);
    expect(LocalStore.userJson, isNull);
    expect(LocalStore.lastActivityMs, isNull);
  });

  test('touch after activity keeps the session alive', () async {
    var now = DateTime.utc(2026, 9, 6, 12);
    IdleSession.clock = () => now;
    await _persistSession(lastActivity: now);

    now = now.add(const Duration(minutes: 29));
    await IdleSession.touch(force: true);
    now = now.add(const Duration(minutes: 29));
    expect(IdleSession.isExpired(), isFalse);

    now = now.add(const Duration(minutes: 2));
    expect(IdleSession.isExpired(), isTrue);
  });

  test('sign-in starts the idle clock', () async {
    const salt = 'test-salt';
    const password = 'password1';
    await LocalStore.saveCredentialVault({
      'idle@hubsom.test': {
        'salt': salt,
        'hash': _hash(password, salt),
        'userJson': _user.toJson(),
      },
    });

    var now = DateTime.utc(2026, 9, 6, 12);
    IdleSession.clock = () => now;
    await AuthRepository(ApiClient()).signIn(
      email: 'idle@hubsom.test',
      password: password,
    );

    expect(LocalStore.lastActivityMs, now.millisecondsSinceEpoch);
    expect(IdleSession.isExpired(), isFalse);
  });

  test('hydrate signs out a session idle for 30 minutes', () async {
    var now = DateTime.utc(2026, 9, 6, 12);
    IdleSession.clock = () => now;
    await _persistSession(
      lastActivity: now.subtract(const Duration(minutes: 30)),
    );

    final controller = AuthController(AuthRepository(ApiClient()));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(controller.state.valueOrNull, isNull);
    expect(LocalStore.sessionToken, isNull);
  });

}
