import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/cart.dart';
import 'package:hubsom_app/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CartController cart;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-cart');
    Hive.init(dir.path);
    await LocalStore.init();
    cart = CartController();
    await cart.clear();
  });

  test('live and shop adds merge into one cart line for header count', () async {
    final product = Product(
      id: 'p1',
      slug: 'mug',
      name: 'Hub mug',
      description: 'Ceramic',
      category: 'home',
      priceGhs: 40,
      images: const ['img'],
      sellerId: 's1',
      stock: 5,
    );

    await cart.addProduct(product, source: 'live', streamId: 'live-1');
    await cart.addProduct(product, source: 'buy-now');

    expect(cart.state.length, 1);
    expect(cart.count, 2);
    expect(cart.state.first.source, 'buy-now');
    expect(cart.state.first.streamId, 'live-1');

    // Persisted and reloaded (as header does via shared provider state).
    final reloaded = CartController();
    expect(reloaded.count, 2);
    expect(reloaded.state.single.productId, 'p1');
  });

  test('legacy split-source cart lines merge on load', () async {
    await LocalStore.saveCart([
      const CartItem(
        productId: 'p2',
        quantity: 1,
        source: 'live',
        name: 'Lamp',
        priceGhs: 80,
        category: 'home',
      ),
      const CartItem(
        productId: 'p2',
        quantity: 2,
        source: 'buy-now',
        name: 'Lamp',
        priceGhs: 80,
        category: 'home',
      ),
    ]);
    final merged = CartController();
    expect(merged.state.length, 1);
    expect(merged.count, 3);
  });
}
