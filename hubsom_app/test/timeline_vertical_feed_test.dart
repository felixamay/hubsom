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
    final dir = Directory.systemTemp.createTempSync('hubsom-timeline');
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

  test('timeline mixes product and video posts for vertical feed', () async {
    final user = HubsomUser.fromJson(
      Map<String, dynamic>.from(jsonDecode(LocalStore.userJson!) as Map),
    );
    await LocalCommerceStore.ensureSellerForUser(user);
    final product = await LocalCommerceStore.createProduct(
      user: user,
      name: 'Timeline lamp',
      description: 'Bright',
      category: 'home',
      priceGhs: 90,
      stock: 4,
      images: const ['a', 'b', 'c'],
    );

    final catalog = CatalogRepository(ApiClient());
    final productPost = await catalog.shareToTimeline(product.id);
    expect(productPost.type, 'product');

    final bytes = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final video = await catalog.createShopVideo(
      bytes: bytes,
      mimeType: 'video/mp4',
      productIds: [product.id],
      caption: 'Lamp demo',
    );

    final feed = await catalog.listTimeline();
    expect(feed.any((p) => p.type == 'product' && p.productId == product.id), isTrue);
    expect(
      feed.any((p) => p.isVideo && (p.videoId == video.id)),
      isTrue,
    );
  });
}
