import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/catalog_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-follow');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  test('follow updates following list and seller followers', () async {
    final sellerUser = HubsomUser.fromJson({
      'id': 'seller-user-1',
      'email': 'seller@hubsom.test',
      'name': 'Seller One',
      'role': 'seller',
      'sellerId': 'store-1',
    });
    await LocalStore.setSessionToken('sess-seller');
    await LocalStore.setUserJson(jsonEncode(sellerUser.toJson()));
    final store = await LocalCommerceStore.ensureSellerForUser(sellerUser);
    expect(store.id, 'store-1');

    final buyer = HubsomUser.fromJson({
      'id': 'buyer-1',
      'email': 'buyer@hubsom.test',
      'name': 'Buyer One',
      'role': 'buyer',
      'followingSellerIds': <String>[],
    });
    await LocalStore.setSessionToken('sess-buyer');
    await LocalStore.setUserJson(jsonEncode(buyer.toJson()));

    HubsomUser? pushed;
    final catalog = CatalogRepository(
      ApiClient(),
      onUserChanged: (u) => pushed = u,
    );

    expect(await catalog.followSeller(store.id), isTrue);
    expect(catalog.isFollowingSeller(store.id), isTrue);
    expect(pushed?.followingSellerIds, contains(store.id));

    final persisted = HubsomUser.fromJson(
      Map<String, dynamic>.from(jsonDecode(LocalStore.userJson!) as Map),
    );
    expect(persisted.followingSellerIds, contains(store.id));

    expect(LocalCommerceStore.followerCount(store.id), 1);
    expect(
      LocalCommerceStore.listFollowers(store.id).first['userId'],
      'buyer-1',
    );

    // Seller dashboard count
    await LocalStore.setUserJson(jsonEncode(sellerUser.toJson()));
    expect(catalog.myFollowerCount(sellerId: store.id), 1);

    await LocalStore.setUserJson(jsonEncode(persisted.toJson()));
    expect(await catalog.unfollowSeller(store.id), isFalse);
    expect(catalog.isFollowingSeller(store.id), isFalse);
    expect(LocalCommerceStore.followerCount(store.id), 0);
  });
}
