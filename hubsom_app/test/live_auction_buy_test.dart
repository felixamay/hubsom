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
  id: 'seller-auc-buy',
  email: 'seller-auc-buy@hubsom.test',
  name: 'Ama Host',
  role: 'seller',
);

const _bidder = HubsomUser(
  id: 'buyer-auc-buy',
  email: 'buyer-auc-buy@hubsom.test',
  name: 'Kojo Bidder',
  role: 'buyer',
);

const _shipping = {
  'recipientName': 'Ama Shop',
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
    final dir = Directory.systemTemp.createTempSync('hubsom-auc-buy');
    Hive.init(dir.path);
    await LocalStore.init();
    await LocalCommerceStore.clearDemoAndCommerce();
    await LocalStore.remove('localOrders');
    await LocalStore.setUserJson(jsonEncode(_seller.toJson()));
    payments = PaymentService(_offlineApi());
  });

  Future<({String streamId, String productId, String auctionId})> goLive({
    int stock = 1,
  }) async {
    final product = await LocalCommerceStore.createProduct(
      user: _seller,
      name: 'Shea butter',
      description: 'Raw',
      category: 'beauty',
      priceGhs: 40,
      stock: stock,
      images: const ['img1', 'img2', 'img3'],
    );
    final stream = await LocalCommerceStore.createStream(
      user: _seller,
      title: 'Night live',
      cover: 'https://cdn.hubsom.test/live-thumb.jpg',
      productIds: [product.id],
      productQuantities: {product.id: stock},
      pinnedProductId: product.id,
      auctionProductId: product.id,
      startingBidGhs: 20,
      askingPriceGhs: 20,
      auctionDurationSeconds: 30,
    );
    return (
      streamId: stream.id,
      productId: product.id,
      auctionId: stream.auction!.id,
    );
  }

  Map<String, dynamic> liveLine(String productId, String streamId) => {
        'productId': productId,
        'quantity': 1,
        'source': 'live',
        'streamId': streamId,
        'name': 'Shea butter',
        'priceGhs': 40,
      };

  test('live checkout cannot take the unit while the lot is still open',
      () async {
    final live = await goLive();
    await LocalCommerceStore.placeBid(
      auctionId: live.auctionId,
      amountGhs: 25,
      bidder: _bidder,
    );

    await expectLater(
      payments.checkout(
        items: [liveLine(live.productId, live.streamId)],
        shipping: _shipping,
        paymentMethods: const ['mtn-momo'],
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('on auction'),
        ),
      ),
    );
    expect(LocalHuberStore.listOrders(), isEmpty);
    expect(
      LocalCommerceStore.getStream(live.streamId)!.offeredQty(live.productId),
      1,
    );

    final ended = LocalCommerceStore.getStream(live.streamId)!.auction!.copyWith(
          endsAt: DateTime.now()
              .toUtc()
              .subtract(const Duration(seconds: 1))
              .toIso8601String(),
        );
    await LocalCommerceStore.updateStream(live.streamId, auction: ended);

    // Clock already hit zero — still reserved until finalize writes the order.
    await expectLater(
      payments.checkout(
        items: [liveLine(live.productId, live.streamId)],
        shipping: _shipping,
        paymentMethods: const ['mtn-momo'],
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('on auction'),
        ),
      ),
    );

    final order = await LocalCommerceStore.finalizeAuction(
      live.streamId,
      autoRelist: false,
    );
    expect(order, isNotNull);
    expect(order!.buyerName, 'Kojo Bidder');
    expect(order.id, startsWith('ord_auc_'));
    expect(
      LocalHuberStore.listOrders()
          .where((o) => o.lines.any((l) => l.productId == live.productId)),
      hasLength(1),
    );
  });

  test('live checkout works again after the lot closes unsold', () async {
    final live = await goLive();
    await LocalCommerceStore.updateStream(
      live.streamId,
      auction: LocalCommerceStore.getStream(live.streamId)!.auction!.copyWith(
            status: 'closed',
          ),
    );

    final paid = await payments.checkout(
      items: [liveLine(live.productId, live.streamId)],
      shipping: _shipping,
      paymentMethods: const ['mtn-momo'],
    );
    expect(paid['ok'], isTrue);
    expect(
      LocalCommerceStore.getStream(live.streamId)!.offeredQty(live.productId),
      0,
    );
    expect(
      LocalHuberStore.listOrders()
          .where((o) => o.lines.any((l) => l.productId == live.productId)),
      hasLength(1),
    );
  });
}
