import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/cart.dart';
import 'package:shared_preferences/shared_preferences.dart';

CartItem _line({required String source, int quantity = 1}) {
  return CartItem(
    productId: 'prod-sneaker',
    quantity: quantity,
    source: source,
    name: 'Red sneaker',
    priceGhs: 80,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-cart-source');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  test('cart +/- only changes the live or shop row for that SKU', () async {
    final cart = CartController();
    await cart.add(_line(source: 'buy-now'));
    await cart.add(_line(source: 'live'));
    expect(cart.state.length, 2);

    await cart.setQuantity('prod-sneaker', 2, source: 'live');
    expect(
      cart.state.firstWhere((e) => e.source == 'live').quantity,
      2,
    );
    expect(
      cart.state.firstWhere((e) => e.source == 'buy-now').quantity,
      1,
    );

    await cart.setQuantity('prod-sneaker', 0, source: 'buy-now');
    expect(cart.state.length, 1);
    expect(cart.state.single.source, 'live');
    expect(cart.state.single.quantity, 2);
  });
}
