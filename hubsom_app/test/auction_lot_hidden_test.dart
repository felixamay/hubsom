import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const seller = HubsomUser(
    id: 'seller-1',
    email: 'seller@hubsom.test',
    name: 'Ama Host',
    role: 'seller',
  );

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-auction-lot');
    Hive.init(dir.path);
    await LocalStore.init();
    await LocalStore.setUserJson(jsonEncode(seller.toJson()));
  });

  test('auction lots stay out of the public store but remain fetchable', () async {
    final store = await LocalCommerceStore.createProduct(
      user: seller,
      name: 'Store beads',
      description: 'For the shop front',
      category: 'fashion',
      priceGhs: 40,
      stock: 5,
      images: const ['a', 'b', 'c'],
    );
    final lot = await LocalCommerceStore.createProduct(
      user: seller,
      name: 'Kente auction lot',
      description: 'Live bidding only',
      category: 'fashion',
      priceGhs: 200,
      stock: 3,
      images: const ['a', 'b', 'c'],
      auctionOnly: true,
    );

    expect(store.isAuctionLot, isFalse);
    expect(lot.isAuctionLot, isTrue);
    expect(lot.supports, ['live-auction']);

    final public = LocalCommerceStore.listProducts();
    expect(public.map((p) => p.id), contains(store.id));
    expect(public.map((p) => p.id), isNot(contains(lot.id)));

    final mine = LocalCommerceStore.listProducts(includeAuctionLots: true);
    expect(mine.map((p) => p.id), containsAll([store.id, lot.id]));

    expect(LocalCommerceStore.getProduct(lot.id)?.id, lot.id);
  });
}
