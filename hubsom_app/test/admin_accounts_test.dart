import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/services/admin_account_store.dart';
import 'package:hubsom_app/core/services/admin_controls_store.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _buyer = HubsomUser(
  id: 'u-buyer',
  email: 'buyer@hubsom.test',
  name: 'Ama Buyer',
  role: 'buyer',
);

Future<void> _init() async {
  AppConfig.load();
  CloudStore.useNetwork = false;
  SharedPreferences.setMockInitialValues({});
  Hive.init(Directory.systemTemp.createTempSync('hubsom-admin-accounts').path);
  await LocalStore.init();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_init);

  test('admin can list, edit, suspend, and delete Hubsom accounts', () async {
    await LocalStore.saveCredentialVault({
      _buyer.email: {
        'email': _buyer.email,
        'name': _buyer.name,
        'role': _buyer.role,
        'userJson': _buyer.toJson(),
      },
    });

    final listed = await AdminAccountStore.list();
    expect(listed.map((a) => a.email), contains(_buyer.email));

    await AdminAccountStore.save(
      _buyer.copyWith(name: 'Ama Edited', role: 'seller'),
    );
    expect(
      AdminAccountStore.cached().firstWhere((a) => a.email == _buyer.email).user.name,
      'Ama Edited',
    );

    await AdminAccountStore.setSuspended(_buyer.email, true);
    expect(
      AdminAccountStore.cached().firstWhere((a) => a.email == _buyer.email).user.suspended,
      isTrue,
    );

    await AdminAccountStore.delete(_buyer.email);
    expect(
      AdminAccountStore.cached().where((a) => a.email == _buyer.email),
      isEmpty,
    );
  });

  test('owner account cannot be deleted or suspended', () async {
    final owner = HubsomUser(
      id: 'u-afia',
      email: 'felixames0808@gmail.com',
      name: 'Felix',
      role: 'admin',
    );
    await LocalStore.saveCredentialVault({
      owner.email: {'email': owner.email, 'userJson': owner.toJson()},
    });
    expect(
      () => AdminAccountStore.setSuspended(owner.email, true),
      throwsA(isA<StateError>()),
    );
    expect(() => AdminAccountStore.delete(owner.email), throwsA(isA<StateError>()));
  });

  test('suspended users lose Hubsom features', () {
    expect(_buyer.copyWith(suspended: true).canUsePath('/wallet'), isFalse);
    expect(_buyer.canUsePath('/wallet'), isTrue);
  });

  test('user feature flags and platform controls gate seller and live paths', () {
    const locked = UserFeatures(canSell: false, canLive: false, canWallet: false);
    expect(locked.allows('/seller/go-live'), isFalse);
    expect(locked.allows('/wallet'), isFalse);
    expect(locked.allows('/marketplace'), isTrue);

    const paused = AdminControls(sellingOpen: false, liveOpen: false);
    expect(paused.allows('/seller'), isFalse);
    expect(paused.allows('/seller/go-live'), isFalse);
    expect(paused.allows('/account'), isTrue);
  });
}
