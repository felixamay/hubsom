import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/catalog_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
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
    final dir = Directory.systemTemp.createTempSync('hubsom-videos-reviews');
    Hive.init(dir.path);
    await LocalStore.init();
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

  test('reviews persist locally and update product aggregates', () async {
    final user = HubsomUser.fromJson(
      Map<String, dynamic>.from(jsonDecode(LocalStore.userJson!) as Map),
    );
    await LocalCommerceStore.ensureSellerForUser(user);
    final product = await LocalCommerceStore.createProduct(
      user: user,
      name: 'Reviewable lamp',
      description: 'Bright',
      category: 'home',
      priceGhs: 80,
      stock: 3,
      images: const ['a', 'b', 'c'],
    );

    final catalog = CatalogRepository(ApiClient());
    final review = await catalog.submitReview(
      product.id,
      rating: 4,
      comment: 'Solid build',
    );
    expect(review.rating, 4);
    expect(await catalog.listReviews(product.id), isNotEmpty);

    final updated = LocalCommerceStore.listProducts()
        .firstWhere((p) => p.id == product.id);
    expect(updated.reviewCount, 1);
    expect(updated.rating, 4.0);
  });

  test('shop video requires linked products and stores bytes by video id',
      () async {
    final user = HubsomUser.fromJson(
      Map<String, dynamic>.from(jsonDecode(LocalStore.userJson!) as Map),
    );
    await LocalCommerceStore.ensureSellerForUser(user);
    final product = await LocalCommerceStore.createProduct(
      user: user,
      name: 'Video mug',
      description: 'Clip',
      category: 'home',
      priceGhs: 25,
      stock: 10,
      images: const ['a', 'b', 'c'],
    );

    final catalog = CatalogRepository(ApiClient());
    final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
    final video = await catalog.createShopVideo(
      bytes: bytes,
      mimeType: 'video/mp4',
      productIds: [product.id],
      caption: 'Check this mug',
    );
    expect(video.productIds, contains(product.id));
    expect(ProductDemoVideoStore.hasVideo(video.id), isTrue);
    expect(await catalog.listShopVideos(), isNotEmpty);
  });
}
