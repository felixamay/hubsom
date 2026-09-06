import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/catalog_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_blob_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/services/product_demo_video_store.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-delete-video');
    Hive.init(dir.path);
    await LocalStore.init();
    await LocalBlobStore.init();
    await ProductDemoVideoStore.init();
    await LocalStore.setSessionToken('sess');
    await LocalStore.setUserJson(
      jsonEncode({
        'id': 'u1',
        'email': 'seller@hubsom.test',
        'name': 'Seller',
        'role': 'seller',
        'sellerId': 'seller-u1',
      }),
    );
  });

  Future<({HubsomUser user, String productId})> _seedSeller() async {
    final user = HubsomUser.fromJson(
      Map<String, dynamic>.from(jsonDecode(LocalStore.userJson!) as Map),
    );
    await LocalCommerceStore.ensureSellerForUser(user);
    final product = await LocalCommerceStore.createProduct(
      user: user,
      name: 'Clip mug',
      description: 'Clip',
      category: 'home',
      priceGhs: 25,
      stock: 10,
      images: const ['a', 'b', 'c'],
    );
    return (user: user, productId: product.id);
  }

  test('owner can delete uploaded shop video and related local data', () async {
    final seed = await _seedSeller();
    final catalog = CatalogRepository(ApiClient());
    final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
    final video = await catalog.createShopVideo(
      bytes: bytes,
      mimeType: 'video/mp4',
      productIds: [seed.productId],
      caption: 'Delete me',
    );
    expect(ProductDemoVideoStore.hasVideo(video.id), isTrue);
    expect(LocalCommerceStore.getShopVideo(video.id), isNotNull);
    expect(
      LocalCommerceStore.listTimelinePosts().any((p) => p.videoId == video.id),
      isTrue,
    );

    await catalog.deleteShopVideo(video.id);

    expect(LocalCommerceStore.getShopVideo(video.id), isNull);
    expect(ProductDemoVideoStore.hasVideo(video.id), isFalse);
    expect(
      LocalCommerceStore.listTimelinePosts().any((p) => p.videoId == video.id),
      isFalse,
    );
    expect(
      (await catalog.listShopVideos()).any((v) => v.id == video.id),
      isFalse,
    );
  });

  test('non-owner cannot delete another seller video', () async {
    final seed = await _seedSeller();
    final catalog = CatalogRepository(ApiClient());
    final video = await catalog.createShopVideo(
      bytes: Uint8List.fromList(const [1, 2, 3]),
      mimeType: 'video/mp4',
      productIds: [seed.productId],
    );

    await LocalStore.setUserJson(
      jsonEncode({
        'id': 'u2',
        'email': 'other@hubsom.test',
        'name': 'Other',
        'role': 'buyer',
      }),
    );

    expect(
      () => catalog.deleteShopVideo(video.id),
      throwsA(isA<StateError>()),
    );
    expect(LocalCommerceStore.getShopVideo(video.id), isNotNull);
  });
}
