import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/auth_repository.dart';
import 'package:hubsom_app/core/repositories/catalog_repository.dart';
import 'package:hubsom_app/core/repositories/seller_repository.dart';
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
    final dir = Directory.systemTemp.createTempSync('hubsom-photo-sync');
    Hive.init(dir.path);
    await LocalStore.init();
    await LocalStore.setUserJson(
      jsonEncode({
        'id': 'u1',
        'email': 'seller@hubsom.test',
        'name': 'Seller',
        'role': 'seller',
        'sellerId': 'seller-u1',
      }),
    );
    await LocalStore.setSessionToken('test-session');
  });

  test('updateStore avatar syncs into account profile image', () async {
    final sellerRepo = SellerRepository(ApiClient());
    const avatar = 'data:image/jpeg;base64,/9j/store-side';
    final updated = await sellerRepo.updateStore({
      'name': 'Accra Crafts',
      'city': 'Accra',
      'bio': 'Handmade',
      'avatar': avatar,
    });
    expect(updated.avatar, avatar);

    final user = HubsomUser.fromJson(
      Map<String, dynamic>.from(jsonDecode(LocalStore.userJson!) as Map),
    );
    expect(user.image, avatar);
  });

  test('updateProfile image syncs into store avatar', () async {
    final auth = AuthRepository(ApiClient());
    // Ensure a store exists first.
    await LocalCommerceStore.ensureSellerForUser(
      HubsomUser.fromJson(
        Map<String, dynamic>.from(jsonDecode(LocalStore.userJson!) as Map),
      ),
    );

    const photo = 'data:image/jpeg;base64,/9j/account-side';
    final user = await auth.updateProfile({
      'name': 'Seller',
      'image': photo,
    });
    expect(user.image, photo);

    final store = LocalCommerceStore.getSeller('seller-u1') ??
        LocalCommerceStore.listSellers().firstWhere(
          (s) => s.ownerUserId == 'u1' || s.id.contains('u1'),
        );
    expect(store.avatar, photo);
  });

  test('users can follow and unfollow a seller account', () async {
    final sellerRepo = SellerRepository(ApiClient());
    final store = await sellerRepo.myStore();
    expect(store, isNotNull);

    // Switch to a buyer account that follows the seller.
    await LocalStore.setUserJson(
      jsonEncode({
        'id': 'buyer-1',
        'email': 'buyer@hubsom.test',
        'name': 'Buyer',
        'role': 'buyer',
        'followingSellerIds': <String>[],
      }),
    );
    await LocalStore.setSessionToken('buyer-session');

    final catalog = CatalogRepository(ApiClient());
    expect(catalog.isFollowingSeller(store!.id), isFalse);
    expect(await catalog.followSeller(store.id), isTrue);
    expect(catalog.isFollowingSeller(store.id), isTrue);

    final following = HubsomUser.fromJson(
      Map<String, dynamic>.from(jsonDecode(LocalStore.userJson!) as Map),
    );
    expect(following.followingSellerIds, contains(store.id));

    expect(await catalog.unfollowSeller(store.id), isFalse);
    expect(catalog.isFollowingSeller(store.id), isFalse);
  });
}
