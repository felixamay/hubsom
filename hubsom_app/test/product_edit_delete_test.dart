import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/auth_repository.dart';
import 'package:hubsom_app/core/repositories/seller_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _jpeg() {
  final image = img.Image(width: 64, height: 64);
  img.fill(image, color: img.ColorRgb8(40, 120, 80));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

String _dataUrl(Uint8List bytes) =>
    'data:image/jpeg;base64,${base64Encode(bytes)}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-product-edit');
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

  test('seller can update and delete their product', () async {
    final repo = SellerRepository(ApiClient());
    final tiny = _dataUrl(_jpeg());
    final created = await repo.createProduct({
      'name': 'Wax print',
      'description': 'Bright Accra wax print cloth',
      'category': 'fashion',
      'priceGhs': 120,
      'stock': 5,
      'images': [tiny, tiny, tiny],
    });
    final id = '${created['id']}';

    final updated = await repo.updateProduct(id, {
      'name': 'Wax print deluxe',
      'description': 'Updated Accra wax print cloth',
      'category': 'fashion',
      'priceGhs': 150,
      'stock': 8,
      'images': [tiny, tiny, tiny, tiny],
    });
    expect(updated['name'], 'Wax print deluxe');
    expect(updated['priceGhs'], 150);
    expect(updated['stock'], 8);
    expect((updated['images'] as List).length, 4);

    final mine = await repo.myProducts();
    expect(mine.any((p) => p.id == id && p.name == 'Wax print deluxe'), isTrue);
    expect(LocalCommerceStore.getProduct(id)?.stock, 8);

    final qty = await repo.updateQuantity(id, 3);
    expect(qty.stock, 3);
    expect(LocalCommerceStore.getProduct(id)?.stock, 3);

    await repo.deleteProduct(id);
    expect(LocalCommerceStore.getProduct(id), isNull);
    final after = await repo.myProducts();
    expect(after.any((p) => p.id == id), isFalse);
  });

  test('create product requires quantity of at least 1', () async {
    final repo = SellerRepository(ApiClient());
    final tiny = _dataUrl(_jpeg());
    expect(
      () => repo.createProduct({
        'name': 'Zero stock bag',
        'description': 'Should not publish without quantity',
        'category': 'fashion',
        'priceGhs': 40,
        'stock': 0,
        'images': [tiny, tiny, tiny],
      }),
      throwsA(isA<AuthException>()),
    );
  });
}
