import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/seller_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-store-avatar');
    Hive.init(dir.path);
    await LocalStore.init();
    await LocalStore.setUserJson(
      jsonEncode({
        'id': 'u1',
        'email': 'seller@hubsom.test',
        'name': 'Seller',
        'role': 'seller',
      }),
    );
  });

  test('updateStore persists profile picture avatar', () async {
    final repo = SellerRepository(ApiClient());
    final before = await repo.myStore();
    expect(before, isNotNull);

    const avatar = 'data:image/jpeg;base64,/9j/4AAQ';
    final updated = await repo.updateStore({
      'name': 'Accra Crafts',
      'city': 'Accra',
      'bio': 'Handmade goods',
      'avatar': avatar,
    });

    expect(updated.avatar, avatar);
    expect(updated.name, 'Accra Crafts');
    expect(LocalCommerceStore.getSeller(updated.id)?.avatar, avatar);
  });
}
