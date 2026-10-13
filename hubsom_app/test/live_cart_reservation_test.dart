import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_huber_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/services/payment_service.dart';
import 'package:hubsom_app/models/stream.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

ApiClient _offlineApi() => ApiClient(
      dio: Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:1',
          connectTimeout: const Duration(milliseconds: 1),
          receiveTimeout: const Duration(milliseconds: 1),
        ),
      ),
    );

const _seller = HubsomUser(
  id: 'seller-live-cart',
  email: 'seller-live-cart@hubsom.test',
  name: 'Ama Host',
  role: 'seller',
);

const _shipping = {
  'recipientName': 'Kojo Buyer',
  'phone': '0240000000',
  'line1': 'East Legon',
  'city': 'Accra',
  'region': 'Greater Accra',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CartController cart;
  late PaymentService payments;

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-live-cart');
    Hive.init(dir.path);
    await LocalStore.init();
    await LocalStore.setUserJson(jsonEncode(_seller.toJson()));
    cart = CartController();
    await cart.clear();
    payments = PaymentService(_offlineApi());
  });

  Future<({LiveStream stream, String productId})> goLive({int qty = 2}) async {
    final product = await LocalCommerceStore.createProduct(
      user: _seller,
      name: 'Shea butter',
      description: 'Raw',
      category: 'beauty',
      priceGhs: 40,
      stock: 8,
      images: const ['img1', 'img2', 'img3'],
    );
    final stream = await LocalCommerceStore.createStream(
      user: _seller,
      title: 'Night live',
      cover: 'https://cdn.hubsom.test/live-thumb.jpg',
      productIds: [product.id],
      productQuantities: {product.id: qty},
      pinnedProductId: product.id,
    );
    return (stream: stream, productId: product.id);
  }

  test('adding a live item to the cart does not consume the bag', () async {
    final live = await goLive(qty: 2);
    final product = LocalCommerceStore.getProduct(live.productId)!;

    await cart.addProduct(
      product,
      source: 'live',
      streamId: live.stream.id,
    );

    expect(cart.count, 1);
    expect(
      LocalCommerceStore.getStream(live.stream.id)!.offeredQty(live.productId),
      2,
    );
    expect(
      LocalHuberStore.listOrders()
          .where((o) => o.lines.any((l) => l.productId == live.productId)),
      isEmpty,
    );
  });

  test('checkout consumes the live bag; abandoning it does not', () async {
    final live = await goLive(qty: 2);
    final product = LocalCommerceStore.getProduct(live.productId)!;

    await cart.addProduct(
      product,
      source: 'live',
      streamId: live.stream.id,
    );
    expect(
      LocalCommerceStore.getStream(live.stream.id)!.offeredQty(live.productId),
      2,
    );

    final paid = await payments.checkout(
      items: cart.state.map((e) => e.toJson()).toList(),
      shipping: _shipping,
      paymentMethods: const ['mtn-momo'],
    );
    expect(paid['ok'], isTrue);
    expect(
      LocalCommerceStore.getStream(live.stream.id)!.offeredQty(live.productId),
      1,
    );
    expect(
      LocalHuberStore.listOrders()
          .where((o) => o.lines.any((l) => l.productId == live.productId)),
      hasLength(1),
    );
    expect(
      LocalHuberStore.listOrders()
          .firstWhere((o) => o.lines.any((l) => l.productId == live.productId))
          .streamId,
      live.stream.id,
    );

    await cart.clear();
    expect(
      LocalCommerceStore.getStream(live.stream.id)!.offeredQty(live.productId),
      1,
    );
  });

  test('a second live checkout can take the last unit, then the bag is empty',
      () async {
    final live = await goLive(qty: 1);
    final product = LocalCommerceStore.getProduct(live.productId)!;
    final line = {
      'productId': product.id,
      'quantity': 1,
      'source': 'live',
      'streamId': live.stream.id,
      'name': product.name,
      'priceGhs': product.priceGhs,
    };

    await payments.checkout(
      items: [line],
      shipping: _shipping,
      paymentMethods: const ['mtn-momo'],
    );
    expect(
      LocalCommerceStore.getStream(live.stream.id)!.offeredQty(live.productId),
      0,
    );

    await expectLater(
      payments.checkout(
        items: [line],
        shipping: _shipping,
        paymentMethods: const ['mtn-momo'],
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Sold out'),
        ),
      ),
    );
    expect(
      LocalCommerceStore.getStream(live.stream.id)!.offeredQty(live.productId),
      0,
    );
    expect(
      LocalHuberStore.listOrders()
          .where((o) => o.lines.any((l) => l.productId == product.id)),
      hasLength(1),
    );
  });

  test('checkout after the host ends still books the live unit', () async {
    final live = await goLive(qty: 1);
    final product = LocalCommerceStore.getProduct(live.productId)!;
    await LocalCommerceStore.updateStream(live.stream.id, end: true);
    expect(LocalCommerceStore.getStream(live.stream.id)!.isLive, isFalse);

    await payments.checkout(
      items: [
        {
          'productId': product.id,
          'quantity': 1,
          'source': 'live',
          'streamId': live.stream.id,
          'name': product.name,
          'priceGhs': product.priceGhs,
        },
      ],
      shipping: _shipping,
      paymentMethods: const ['mtn-momo'],
    );
    expect(
      LocalCommerceStore.getStream(live.stream.id)!.offeredQty(live.productId),
      0,
    );
    expect(
      LocalHuberStore.listOrders()
          .where((o) => o.lines.any((l) => l.productId == product.id)),
      hasLength(1),
    );
  });

  test('stale cloud hydrate cannot restock a sold live bag for a second checkout',
      () async {
    final live = await goLive(qty: 1);
    final product = LocalCommerceStore.getProduct(live.productId)!;
    final line = {
      'productId': product.id,
      'quantity': 1,
      'source': 'live',
      'streamId': live.stream.id,
      'name': product.name,
      'priceGhs': product.priceGhs,
    };

    await payments.checkout(
      items: [line],
      shipping: _shipping,
      paymentMethods: const ['mtn-momo'],
    );
    expect(
      LocalCommerceStore.getStream(live.stream.id)!.offeredQty(live.productId),
      0,
    );

    // Same replace hydrateLocalCache used to do: cloud still has the
    // pre-checkout bag because the stream upsert had not landed.
    final staleCloud = live.stream.toJson();
    final merged = CloudStore.mergeStreamDocs(
      localKey: 'localStreams',
      incoming: [staleCloud],
    );
    await LocalStore.setString('localStreams', jsonEncode(merged));

    expect(
      LocalCommerceStore.getStream(live.stream.id)!.offeredQty(live.productId),
      0,
    );
    await expectLater(
      payments.checkout(
        items: [line],
        shipping: _shipping,
        paymentMethods: const ['mtn-momo'],
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Sold out'),
        ),
      ),
    );
    expect(
      LocalHuberStore.listOrders()
          .where((o) => o.lines.any((l) => l.productId == product.id)),
      hasLength(1),
    );
  });
}
