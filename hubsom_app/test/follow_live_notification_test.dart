import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/catalog_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_notification_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seller = HubsomUser(
  id: 'seller-live-1',
  email: 'host@hubsom.test',
  name: 'Ama Host',
  role: 'seller',
  sellerId: 'store-live-1',
);

const _buyer = HubsomUser(
  id: 'buyer-live-1',
  email: 'fan@hubsom.test',
  name: 'Kojo Fan',
  role: 'buyer',
);

Future<void> _as(HubsomUser user) async {
  await LocalStore.setSessionToken('sess-${user.id}');
  await LocalStore.setUserJson(jsonEncode(user.toJson()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-live-alerts');
    Hive.init(dir.path);
    await LocalStore.init();
    await LocalStore.setString(LocalNotificationStore.key, null);
    await LocalStore.setString('localSellerFollowers', null);
  });

  Future<({String productId, String storeId})> _readyStore() async {
    await _as(_seller);
    final product = await LocalCommerceStore.createProduct(
      user: _seller,
      name: 'Shea butter',
      description: 'Raw',
      category: 'beauty',
      priceGhs: 40,
      stock: 5,
      images: const ['img1', 'img2', 'img3'],
    );
    final store = await LocalCommerceStore.ensureSellerForUser(_seller);
    return (productId: product.id, storeId: store.id);
  }

  Future<void> _goLive({
    required String productId,
    required String title,
  }) async {
    await _as(_seller);
    final stream = await LocalCommerceStore.createStream(
      user: _seller,
      title: title,
      cover: 'https://cdn.hubsom.test/live-thumb.jpg',
      productIds: [productId],
    );
    await LocalNotificationStore.notifySellerWentLive(stream);
  }

  test('followers are notified when a store they follow goes live', () async {
    final ready = await _readyStore();

    await _as(_buyer);
    final catalog = CatalogRepository(ApiClient());
    expect(await catalog.followSeller(ready.storeId), isTrue);

    await _goLive(productId: ready.productId, title: 'Sunday shea live');

    final notes = LocalNotificationStore.forUser(_buyer.id);
    expect(notes, isNotEmpty);
    expect(notes.first.title, contains('is live'));
    expect(notes.first.body, 'Sunday shea live');
    expect(notes.first.route, startsWith('/live/'));
    expect(notes.first.read, isFalse);
    expect(LocalNotificationStore.forUser(_seller.id), isEmpty);
  });

  test('unfollowed accounts do not get a live alert', () async {
    final ready = await _readyStore();

    await _as(_buyer);
    final catalog = CatalogRepository(ApiClient());
    await catalog.followSeller(ready.storeId);
    expect(await catalog.unfollowSeller(ready.storeId), isFalse);
    expect(LocalCommerceStore.listFollowers(ready.storeId), isEmpty);

    await _goLive(productId: ready.productId, title: 'Quiet show');

    expect(LocalNotificationStore.forUser(_buyer.id), isEmpty);
  });
}
