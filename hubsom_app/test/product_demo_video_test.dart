import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/seller_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/services/product_demo_video_store.dart';
import 'package:hubsom_app/models/product.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _tinyJpeg() {
  final image = img.Image(width: 32, height: 32);
  img.fill(image, color: img.ColorRgb8(10, 80, 40));
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

String _dataUrl() => 'data:image/jpeg;base64,${base64Encode(_tinyJpeg())}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-demo-video');
    Hive.init(dir.path);
    await LocalStore.init();
    await ProductDemoVideoStore.init();
    await LocalStore.setUserJson(
      jsonEncode({
        'id': 'u-video',
        'email': 'video@hubsom.test',
        'name': 'Video Seller',
        'role': 'seller',
      }),
    );
  });

  test('product JSON round-trips hasDemoVideo', () {
    final product = Product(
      id: 'p1',
      slug: 'p1',
      name: 'Demo bag',
      description: 'A short demo listing',
      category: 'fashion',
      priceGhs: 40,
      images: const ['a', 'b', 'c'],
      sellerId: 's1',
      stock: 2,
      hasDemoVideo: true,
    );
    final again = Product.fromJson(product.toJson());
    expect(again.hasDemoVideo, isTrue);
    expect(again.showsDemoVideo, isTrue);
  });

  test('createProduct with demo video stores bytes for playback', () async {
    final repo = SellerRepository(ApiClient());
    final photo = _dataUrl();
    final videoBytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
    final created = await repo.createProduct(
      {
        'name': 'Kente scarf',
        'description': 'Bright handmade kente scarf',
        'category': 'fashion',
        'priceGhs': 90,
        'stock': 3,
        'images': [photo, photo, photo],
      },
      demoVideoBytes: videoBytes,
      demoVideoMimeType: 'video/mp4',
    );

    expect(created['hasDemoVideo'], isTrue);
    final id = created['id'] as String;
    final stored = await ProductDemoVideoStore.load(id);
    expect(stored, isNotNull);
    expect(stored!.bytes, videoBytes);
    expect(stored.mimeType, 'video/mp4');

    final mine = await repo.myProducts();
    expect(mine.any((p) => p.id == id && p.hasDemoVideo), isTrue);
  });
}
