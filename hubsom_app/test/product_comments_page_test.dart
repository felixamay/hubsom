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
    final dir = Directory.systemTemp.createTempSync('hubsom-comments');
    Hive.init(dir.path);
    await LocalStore.init();
    await LocalStore.setSessionToken('sess');
    await LocalStore.setUserJson(
      jsonEncode({
        'id': 'buyer-1',
        'email': 'buyer@hubsom.test',
        'name': 'Buyer',
        'role': 'buyer',
      }),
    );
  });

  test('comments can be listed and added for a product', () async {
    final seller = HubsomUser(
      id: 'u-seller',
      email: 's@hubsom.test',
      name: 'Seller',
      role: 'seller',
      sellerId: 'seller-u-seller',
    );
    await LocalCommerceStore.ensureSellerForUser(seller);
    final product = await LocalCommerceStore.createProduct(
      user: seller,
      name: 'Commentable mug',
      description: 'Ceramic',
      category: 'home',
      priceGhs: 40,
      stock: 5,
      images: const ['a', 'b', 'c'],
    );

    final catalog = CatalogRepository(ApiClient());
    expect(await catalog.listComments(product.id), isEmpty);

    final added = await catalog.addComment(product.id, 'Looks great');
    expect(added.text, 'Looks great');
    expect(added.productId, product.id);

    final listed = await catalog.listComments(product.id);
    expect(listed, isNotEmpty);
    expect(listed.first.text, 'Looks great');
  });
}
