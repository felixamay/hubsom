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
    final dir = Directory.systemTemp.createTempSync('hubsom-publish-fast');
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

  test('createShopVideo returns before cloud upload finishes', () async {
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

    final catalog = CatalogRepository(ApiClient());
    final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
    final thumb = Uint8List.fromList(List<int>.generate(48, (i) => 255 - i));
    final sw = Stopwatch()..start();
    final video = await catalog.createShopVideo(
      bytes: bytes,
      mimeType: 'video/mp4',
      productIds: [product.id],
      caption: 'Fast publish',
      thumbnailBytes: thumb,
    );
    sw.stop();

    expect(sw.elapsedMilliseconds, lessThan(5000));
    expect(video.videoPosterUrl, isNotNull);
    expect(ProductDemoVideoStore.hasVideo(video.id), isTrue);
    expect(LocalCommerceStore.getShopVideo(video.id), isNotNull);
  });
}
