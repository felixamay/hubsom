import 'dart:io';
import 'dart:typed_data';

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
import 'package:hubsom_app/models/product.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.body);

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HubsomUser seller;

  setUp(() async {
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-checkout');
    Hive.init(dir.path);
    await LocalStore.init();
    await LocalStore.remove('localOrders');
    await LocalStore.remove('localProducts');
    await LocalStore.remove('localSellers');
    seller = const HubsomUser(
      id: 'seller-1',
      email: 'seller@hubsom.test',
      name: 'Ama Seller',
      role: 'seller',
    );
  });

  Future<Product> listItem({
    double price = 200,
    int stock = 4,
    FlashSale? sale,
  }) async {
    var product = await LocalCommerceStore.createProduct(
      user: seller,
      name: 'Kente scarf',
      description: 'Handwoven',
      category: 'fashion',
      priceGhs: price,
      stock: stock,
      images: const ['img1', 'img2', 'img3'],
    );
    if (sale != null) {
      product = Product(
        id: product.id,
        slug: product.slug,
        name: product.name,
        description: product.description,
        category: product.category,
        priceGhs: product.priceGhs,
        images: product.images,
        sellerId: product.sellerId,
        stock: product.stock,
        flashSale: sale,
      );
      await LocalCommerceStore.updateProduct(product);
    }
    return product;
  }

  test('parseRemoteCheckout accepts Next.js orderId payloads', () {
    final parsed = PaymentService.parseRemoteCheckout(
      '{"orderId":"ord_abc","status":"pending_payment","subtotalGhs":80}',
    );
    expect(parsed, isNotNull);
    expect(parsed!['orderId'], 'ord_abc');
    expect(PaymentService.checkoutOrderId(parsed), 'ord_abc');
  });

  test('parseRemoteCheckout rejects HTML and error JSON', () {
    expect(
      PaymentService.parseRemoteCheckout('<!doctype html><html></html>'),
      isNull,
    );
    expect(
      PaymentService.parseRemoteCheckout('{"error":"Sign in required"}'),
      isNull,
    );
    expect(PaymentService.parseRemoteCheckout('{"ok":true}'), isNull);
  });

  test('offline checkout stays pending_payment and uses catalog price', () async {
    final product = await listItem(price: 200, stock: 4);
    final res = await PaymentService.placeOfflineCheckout(
      items: [
        {
          'productId': product.id,
          'quantity': 2,
          'priceGhs': 0,
          'name': 'spoofed',
        },
      ],
      shipping: {
        'recipientName': 'Kojo Buyer',
        'phone': '0241111111',
        'line1': '12 Spintex Rd',
        'city': 'Accra',
        'region': 'Greater Accra',
      },
      paymentMethods: const ['wallet'],
    );

    expect(res['status'], 'pending_payment');
    expect(res['subtotalGhs'], 400);
    expect(res['order']['status'], 'pending_payment');
    expect(res['order']['lines'][0]['unitPriceGhs'], 200);
    expect(LocalHuberStore.getOrder(res['orderId'] as String)?.status, 'pending_payment');
    expect(LocalCommerceStore.getProduct(product.id)?.stock, 2);
  });

  test('offline checkout rejects negative quantity and leaves stock', () async {
    final product = await listItem(stock: 3);
    await expectLater(
      PaymentService.placeOfflineCheckout(
        items: [
          {'productId': product.id, 'quantity': -10, 'priceGhs': 200},
        ],
        shipping: {
          'recipientName': 'Kojo Buyer',
          'phone': '0241111111',
          'line1': '12 Spintex Rd',
          'city': 'Accra',
          'region': 'Greater Accra',
        },
        paymentMethods: const ['cash-on-delivery'],
      ),
      throwsA(isA<StateError>()),
    );
    expect(LocalCommerceStore.getProduct(product.id)?.stock, 3);
    expect(LocalHuberStore.listOrders(), isEmpty);
  });

  test('offline checkout restores stock if a later line fails', () async {
    final inStock = await listItem(stock: 2);
    await expectLater(
      PaymentService.placeOfflineCheckout(
        items: [
          {'productId': inStock.id, 'quantity': 1},
          {'productId': 'missing-sku', 'quantity': 1},
        ],
        shipping: {
          'recipientName': 'Kojo Buyer',
          'phone': '0241111111',
          'line1': '12 Spintex Rd',
          'city': 'Accra',
          'region': 'Greater Accra',
        },
        paymentMethods: const ['mtn-momo'],
      ),
      throwsA(isA<StateError>()),
    );
    expect(LocalCommerceStore.getProduct(inStock.id)?.stock, 2);
    expect(LocalHuberStore.listOrders(), isEmpty);
  });

  test('expired flash sale does not undercharge', () {
    const product = Product(
      id: 'p1',
      slug: 'p1',
      name: 'Lamp',
      description: '',
      category: 'home',
      priceGhs: 100,
      images: ['a', 'b', 'c'],
      sellerId: 's1',
      stock: 1,
      flashSale: FlashSale(endsAt: '2020-01-01T00:00:00.000Z', discountPct: 90),
    );
    expect(
      PaymentService.catalogUnitPrice(
        product,
        now: DateTime.utc(2026, 11, 20),
      ),
      100,
    );
  });

  test('checkout honors Next.js orderId and does not mint a local paid order', () async {
    AppConfig.load();
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:3000',
        responseType: ResponseType.plain,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    dio.httpClientAdapter = _FixedAdapter(
      '{"orderId":"ord_server","status":"pending_payment","subtotalGhs":80}',
    );
    final product = await listItem(stock: 2);
    final res = await PaymentService(ApiClient(dio: dio)).checkout(
      items: [
        {'productId': product.id, 'quantity': 1, 'priceGhs': 0},
      ],
      shipping: {
        'recipientName': 'Kojo Buyer',
        'phone': '0241111111',
        'line1': '12 Spintex Rd',
        'city': 'Accra',
        'region': 'Greater Accra',
      },
      paymentMethods: const ['mtn-momo'],
    );
    expect(res['orderId'], 'ord_server');
    expect(LocalHuberStore.listOrders(), isEmpty);
    expect(LocalCommerceStore.getProduct(product.id)?.stock, 2);
  });

  test('HTML Hosting rewrite falls back without marking the order paid', () async {
    AppConfig.load();
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:3000',
        responseType: ResponseType.plain,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    dio.httpClientAdapter = _FixedAdapter('<!doctype html><html></html>');
    final product = await listItem(price: 150, stock: 3);
    final res = await PaymentService(ApiClient(dio: dio)).checkout(
      items: [
        {'productId': product.id, 'quantity': 1, 'priceGhs': 0},
      ],
      shipping: {
        'recipientName': 'Kojo Buyer',
        'phone': '0241111111',
        'line1': '12 Spintex Rd',
        'city': 'Accra',
        'region': 'Greater Accra',
      },
      paymentMethods: const ['wallet'],
    );
    expect(res['status'], 'pending_payment');
    expect(res['subtotalGhs'], 150);
    expect(LocalHuberStore.getOrder(res['orderId'] as String)?.status, 'pending_payment');
    expect(LocalCommerceStore.getProduct(product.id)?.stock, 2);
  });

  test('discountPct above 100 cannot go negative', () {
    const product = Product(
      id: 'p1',
      slug: 'p1',
      name: 'Lamp',
      description: '',
      category: 'home',
      priceGhs: 100,
      images: ['a', 'b', 'c'],
      sellerId: 's1',
      stock: 1,
      flashSale: FlashSale(endsAt: '2099-01-01T00:00:00.000Z', discountPct: 150),
    );
    expect(PaymentService.catalogUnitPrice(product), 0);
  });
}
