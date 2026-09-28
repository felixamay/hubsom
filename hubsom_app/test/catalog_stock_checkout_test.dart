import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_huber_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/services/payment_service.dart';
import 'package:hubsom_app/models/order.dart';
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
  id: 'seller-stock',
  email: 'seller-stock@hubsom.test',
  name: 'Ama Host',
  role: 'seller',
);

const _bidder = HubsomUser(
  id: 'buyer-stock',
  email: 'buyer-stock@hubsom.test',
  name: 'Kojo Buyer',
  role: 'buyer',
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

  late PaymentService payments;

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-catalog-stock');
    Hive.init(dir.path);
    await LocalStore.init();
    await LocalCommerceStore.clearDemoAndCommerce();
    await LocalStore.remove('localOrders');
    await LocalStore.setUserJson(jsonEncode(_seller.toJson()));
    payments = PaymentService(_offlineApi());
  });

  Future<String> listOne({int stock = 1}) async {
    final product = await LocalCommerceStore.createProduct(
      user: _seller,
      name: 'Shea butter',
      description: 'Raw',
      category: 'beauty',
      priceGhs: 40,
      stock: stock,
      images: const ['img1', 'img2', 'img3'],
    );
    return product.id;
  }

  Map<String, dynamic> shopLine(String productId, {int quantity = 1}) => {
        'productId': productId,
        'quantity': quantity,
        'name': 'Shea butter',
        'priceGhs': 40,
        'sellerId': 'seller-u-${_seller.id}',
      };

  test('shop checkout cannot sell more units than catalog stock', () async {
    final productId = await listOne();

    final first = await payments.checkout(
      items: [shopLine(productId)],
      shipping: _shipping,
      paymentMethods: const ['mtn-momo'],
    );
    expect(first['ok'], isTrue);
    expect(
      LocalHuberStore.listOrders()
          .where((o) => o.lines.any((l) => l.productId == productId)),
      hasLength(1),
    );

    await expectLater(
      payments.checkout(
        items: [shopLine(productId)],
        shipping: _shipping,
        paymentMethods: const ['mtn-momo'],
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('sold out'),
        ),
      ),
    );
    expect(
      LocalHuberStore.listOrders()
          .where((o) => o.lines.any((l) => l.productId == productId)),
      hasLength(1),
    );
  });

  test('a single shop checkout cannot take more than remaining stock', () async {
    final productId = await listOne();

    await expectLater(
      payments.checkout(
        items: [shopLine(productId, quantity: 5)],
        shipping: _shipping,
        paymentMethods: const ['mtn-momo'],
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('only has 1 left in stock'),
        ),
      ),
    );
    expect(LocalHuberStore.listOrders(), isEmpty);
  });

  test('shop checkout leaves the live bag unit for the auction winner',
      () async {
    final productId = await listOne();
    await LocalCommerceStore.createStream(
      user: _seller,
      title: 'Night live',
      cover: 'https://cdn.hubsom.test/live-thumb.jpg',
      productIds: [productId],
      productQuantities: {productId: 1},
      pinnedProductId: productId,
    );

    await expectLater(
      payments.checkout(
        items: [shopLine(productId)],
        shipping: _shipping,
        paymentMethods: const ['mtn-momo'],
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('sold out'),
        ),
      ),
    );
    expect(LocalHuberStore.listOrders(), isEmpty);
  });

  test('winning auction does not invent a paid order after shop sold the unit',
      () async {
    final productId = await listOne(stock: 1);
    final stream = await LocalCommerceStore.createStream(
      user: _seller,
      title: 'Night live',
      cover: 'https://cdn.hubsom.test/live-thumb.jpg',
      productIds: [productId],
      productQuantities: {productId: 1},
      pinnedProductId: productId,
      auctionProductId: productId,
      startingBidGhs: 20,
      askingPriceGhs: 20,
      auctionDurationSeconds: 30,
    );

    await LocalCommerceStore.placeBid(
      auctionId: stream.auction!.id,
      amountGhs: 25,
      bidder: _bidder,
    );

    // A shop order can land from another path before the clock hits zero.
    await LocalHuberStore.saveOrder(
      Order(
        id: 'ord_shop_first',
        subtotalGhs: 40,
        status: 'paid',
        userId: 'other-buyer',
        buyerName: 'Ama Shop',
        lines: [
          OrderLine(
            productId: productId,
            sellerId: stream.sellerId,
            name: 'Shea butter',
            quantity: 1,
            unitPriceGhs: 40,
            lineTotalGhs: 40,
            category: 'beauty',
          ),
        ],
        shipping: const OrderShipping(
          recipientName: 'Ama Shop',
          phone: '0200000000',
          line1: 'Osu',
          city: 'Accra',
          region: 'Greater Accra',
        ),
        paymentMethods: const ['mtn-momo'],
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );

    final ended = LocalCommerceStore.getStream(stream.id)!.auction!.copyWith(
          endsAt: DateTime.now()
              .toUtc()
              .subtract(const Duration(seconds: 1))
              .toIso8601String(),
        );
    await LocalCommerceStore.updateStream(stream.id, auction: ended);

    final order = await LocalCommerceStore.finalizeAuction(
      stream.id,
      autoRelist: false,
    );
    expect(order, isNull);
    expect(
      LocalHuberStore.listOrders().where((o) => o.id.startsWith('ord_auc_')),
      isEmpty,
    );
    expect(
      LocalCommerceStore.getStream(stream.id)!.auction!.status,
      'closed',
    );
  });

  test('go-live cannot put already-sold catalog units on the live bag',
      () async {
    final productId = await listOne(stock: 2);

    final sold = await payments.checkout(
      items: [shopLine(productId)],
      shipping: _shipping,
      paymentMethods: const ['mtn-momo'],
    );
    expect(sold['ok'], isTrue);
    expect(LocalCommerceStore.availableCatalogQty(productId), 1);

    await expectLater(
      LocalCommerceStore.createStream(
        user: _seller,
        title: 'Night live',
        cover: 'https://cdn.hubsom.test/live-thumb.jpg',
        productIds: [productId],
        productQuantities: {productId: 2},
        pinnedProductId: productId,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('only has 1 left in stock'),
        ),
      ),
    );
    expect(LocalCommerceStore.listStreams(), isEmpty);
  });

  test('go-live without a quantity uses remaining catalog, not listing stock',
      () async {
    final productId = await listOne(stock: 2);
    await payments.checkout(
      items: [shopLine(productId)],
      shipping: _shipping,
      paymentMethods: const ['mtn-momo'],
    );

    final stream = await LocalCommerceStore.createStream(
      user: _seller,
      title: 'Night live',
      cover: 'https://cdn.hubsom.test/live-thumb.jpg',
      productIds: [productId],
      pinnedProductId: productId,
    );
    expect(stream.productQuantities[productId], 1);
    expect(stream.offeredQty(productId, fallback: 2), 1);
  });

  test('adding a product mid-live cannot exceed remaining catalog', () async {
    final firstId = await listOne(stock: 1);
    final extraId = await listOne(stock: 2);
    await payments.checkout(
      items: [shopLine(extraId)],
      shipping: _shipping,
      paymentMethods: const ['mtn-momo'],
    );

    final stream = await LocalCommerceStore.createStream(
      user: _seller,
      title: 'Night live',
      cover: 'https://cdn.hubsom.test/live-thumb.jpg',
      productIds: [firstId],
      productQuantities: {firstId: 1},
      pinnedProductId: firstId,
    );

    await expectLater(
      LocalCommerceStore.addProductsToStream(
        streamId: stream.id,
        user: _seller,
        productIds: [extraId],
        quantities: {extraId: 2},
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('only has 1 left in stock'),
        ),
      ),
    );
    expect(
      LocalCommerceStore.getStream(stream.id)!.productIds,
      isNot(contains(extraId)),
    );
  });

  test('auto-relist does not open a lot after catalog is gone', () async {
    final productId = await listOne(stock: 2);
    final stream = await LocalCommerceStore.createStream(
      user: _seller,
      title: 'Night live',
      cover: 'https://cdn.hubsom.test/live-thumb.jpg',
      productIds: [productId],
      productQuantities: {productId: 2},
      pinnedProductId: productId,
      auctionProductId: productId,
      startingBidGhs: 20,
      askingPriceGhs: 20,
      auctionDurationSeconds: 30,
    );
    final firstLotId = stream.auction!.id;

    // A shop path wrote a paid order while the bag still showed 2.
    // One catalog unit remains for this winner; the leftover bag unit
    // must not become a second auction.
    await LocalHuberStore.saveOrder(
      Order(
        id: 'ord_shop_first',
        subtotalGhs: 40,
        status: 'paid',
        userId: 'other-buyer',
        buyerName: 'Ama Shop',
        lines: [
          OrderLine(
            productId: productId,
            sellerId: stream.sellerId,
            name: 'Shea butter',
            quantity: 1,
            unitPriceGhs: 40,
            lineTotalGhs: 40,
            category: 'beauty',
          ),
        ],
        shipping: const OrderShipping(
          recipientName: 'Ama Shop',
          phone: '0200000000',
          line1: 'Osu',
          city: 'Accra',
          region: 'Greater Accra',
        ),
        paymentMethods: const ['mtn-momo'],
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );

    await LocalCommerceStore.placeBid(
      auctionId: firstLotId,
      amountGhs: 25,
      bidder: _bidder,
    );
    final ended = LocalCommerceStore.getStream(stream.id)!.auction!.copyWith(
          endsAt: DateTime.now()
              .toUtc()
              .subtract(const Duration(seconds: 1))
              .toIso8601String(),
        );
    await LocalCommerceStore.updateStream(stream.id, auction: ended);

    final order = await LocalCommerceStore.finalizeAuction(stream.id);
    expect(order, isNotNull);
    expect(order!.id, 'ord_auc_$firstLotId');
    final after = LocalCommerceStore.getStream(stream.id)!.auction!;
    expect(after.id, firstLotId);
    expect(after.status, 'sold');
    expect(after.isOpen, isFalse);
    expect(LocalCommerceStore.availableCatalogQty(productId), 0);
  });

  test('shop checkout cannot pay for a listing the seller already deleted',
      () async {
    final productId = await listOne(stock: 1);
    await LocalCommerceStore.deleteProduct(productId);

    expect(LocalCommerceStore.availableCatalogQty(productId), 0);
    await expectLater(
      payments.checkout(
        items: [shopLine(productId)],
        shipping: _shipping,
        paymentMethods: const ['mtn-momo'],
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('no longer for sale'),
        ),
      ),
    );
    expect(LocalHuberStore.listOrders(), isEmpty);
  });

  test('deleting a live listing closes the lot and does not invent a winner',
      () async {
    final productId = await listOne(stock: 1);
    final stream = await LocalCommerceStore.createStream(
      user: _seller,
      title: 'Night live',
      cover: 'https://cdn.hubsom.test/live-thumb.jpg',
      productIds: [productId],
      productQuantities: {productId: 1},
      pinnedProductId: productId,
      auctionProductId: productId,
      startingBidGhs: 20,
      askingPriceGhs: 20,
      auctionDurationSeconds: 30,
    );
    await LocalCommerceStore.placeBid(
      auctionId: stream.auction!.id,
      amountGhs: 25,
      bidder: _bidder,
    );

    await LocalCommerceStore.deleteProduct(productId);

    final afterDelete = LocalCommerceStore.getStream(stream.id)!;
    expect(afterDelete.productIds, isNot(contains(productId)));
    expect(afterDelete.productQuantities.containsKey(productId), isFalse);
    expect(afterDelete.auction?.productId, productId);
    expect(afterDelete.auction?.status, 'closed');
    expect(afterDelete.auction?.isUnsettledLot, isFalse);

    final order = await LocalCommerceStore.finalizeAuction(stream.id);
    expect(order, isNull);
    expect(LocalHuberStore.listOrders(), isEmpty);
  });
}
