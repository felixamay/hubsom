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
import 'package:hubsom_app/core/services/product_photo_compress.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _jpeg({required int width, required int height, int quality = 95}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(40, 120, 80));
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

String _dataUrl(Uint8List bytes) =>
    'data:image/jpeg;base64,${base64Encode(bytes)}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-product');
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

  test('compressProductPhoto shrinks large camera-style JPEGs under 700KB', () async {
    final raw = _jpeg(width: 4000, height: 3000);
    expect(raw.lengthInBytes, greaterThan(50 * 1024));
    final compressed = await compressProductPhoto(raw);
    expect(compressed.lengthInBytes, lessThan(700000));
    expect(compressed.lengthInBytes, lessThan(raw.lengthInBytes));
    final decoded = img.decodeJpg(compressed);
    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(1280));
  });

  test('createProduct is visible to myProducts for go-live', () async {
    final repo = SellerRepository(ApiClient());
    final tiny = _dataUrl(_jpeg(width: 64, height: 64));
    final created = await repo.createProduct({
      'name': 'Wax print',
      'description': 'Bright Accra wax print cloth',
      'category': 'fashion',
      'priceGhs': 120,
      'stock': 5,
      'images': [tiny, tiny, tiny],
    });
    expect(created['id'], isNotNull);

    final mine = await repo.myProducts();
    expect(mine, isNotEmpty);
    expect(mine.any((p) => p.id == created['id']), isTrue);
    expect(mine.firstWhere((p) => p.id == created['id']).images.length, 3);

    final session = LocalStore.userJson!;
    expect(session.contains('seller-u1'), isTrue);
  });
}
