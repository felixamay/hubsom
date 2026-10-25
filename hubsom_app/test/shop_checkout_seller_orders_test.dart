import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/order_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_huber_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/services/payment_service.dart';
import 'package:hubsom_app/models/order.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoApiAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      message: 'no api',
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HubsomUser seller;
  late HubsomUser buyer;
  late PaymentService payments;
  late OrderRepository orders;

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-shop-checkout');
    Hive.init(dir.path);
    await LocalStore.init();

    seller = const HubsomUser(
      id: 'seller-1',
      email: 'seller@hubsom.test',
      name: 'Ama Host',
      role: 'seller',
      sellerId: 'seller-1',
    );
    buyer = const HubsomUser(
      id: 'buyer-1',
      email: 'buyer@hubsom.test',
      name: 'Kojo Buyer',
      role: 'buyer',
    );

    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1'));
    dio.httpClientAdapter = _NoApiAdapter();
    final api = ApiClient(dio: dio);
    payments = PaymentService(api);
    orders = OrderRepository(api);
  });

  test('shop checkout stamps sellerId so seller Orders can fulfill the sale',
      () async {
    await LocalStore.setUserJson(jsonEncode(seller.toJson()));
    final product = await LocalCommerceStore.createProduct(
      user: seller,
      name: 'Wax print',
      description: 'Bright Accra wax print',
      category: 'fashion',
      priceGhs: 120,
      stock: 2,
      images: const ['img1', 'img2', 'img3'],
    );
    expect(product.sellerId, 'seller-1');

    await LocalStore.setUserJson(jsonEncode(buyer.toJson()));
    // Reproduce today's cart payload: no sellerId on the line.
    final result = await payments.checkout(
      items: [
        {
          'productId': product.id,
          'quantity': 1,
          'source': 'buy-now',
          'name': product.name,
          'priceGhs': product.priceGhs,
          'image': product.images.first,
          'category': product.category,
        },
      ],
      shipping: const {
        'recipientName': 'Kojo Buyer',
        'phone': '0241111111',
        'line1': '12 Spintex Rd',
        'city': 'Accra',
        'region': 'Greater Accra',
      },
      paymentMethods: const ['mtn-momo'],
    );

    final orderJson = Map<String, dynamic>.from(result['order'] as Map);
    expect(orderJson['status'], 'paid');
    final lines = (orderJson['lines'] as List).cast<Map>();
    expect(lines.first['sellerId'], 'seller-1');

    await LocalStore.setUserJson(jsonEncode(seller.toJson()));
    final sellerOrders = await orders.sellerOrders();
    expect(sellerOrders.map((o) => o.id), contains(orderJson['id']));
    expect(sellerOrders.first.lines.first.sellerId, 'seller-1');

    await LocalStore.setUserJson(
      jsonEncode(
        const HubsomUser(
          id: 'other-seller',
          email: 'other@hubsom.test',
          name: 'Other Store',
          role: 'seller',
          sellerId: 'seller-other',
        ).toJson(),
      ),
    );
    final otherOrders = await orders.sellerOrders();
    expect(otherOrders.map((o) => o.id), isNot(contains(orderJson['id'])));
  });

  test('seller Orders still finds a legacy paid sale missing line.sellerId',
      () async {
    await LocalStore.setUserJson(jsonEncode(seller.toJson()));
    final product = await LocalCommerceStore.createProduct(
      user: seller,
      name: 'Kente scarf',
      description: 'Handwoven',
      category: 'fashion',
      priceGhs: 80,
      stock: 1,
      images: const ['img1', 'img2', 'img3'],
    );

    await LocalStore.setUserJson(jsonEncode(buyer.toJson()));
    final result = await payments.checkout(
      items: [
        {
          'productId': product.id,
          'quantity': 1,
          'source': 'buy-now',
          'name': product.name,
          'priceGhs': product.priceGhs,
          'category': product.category,
        },
      ],
      shipping: const {
        'recipientName': 'Kojo Buyer',
        'phone': '0241111111',
        'line1': '12 Spintex Rd',
        'city': 'Accra',
        'region': 'Greater Accra',
      },
      paymentMethods: const ['mtn-momo'],
    );
    final orderId = (result['order'] as Map)['id'] as String;

    final saved = LocalHuberStore.getOrder(orderId)!;
    await LocalHuberStore.saveOrder(
      Order(
        id: saved.id,
        subtotalGhs: saved.subtotalGhs,
        status: saved.status,
        userId: saved.userId,
        buyerName: saved.buyerName,
        buyerEmail: saved.buyerEmail,
        lines: [
          OrderLine(
            productId: product.id,
            name: product.name,
            quantity: 1,
            unitPriceGhs: product.priceGhs,
            lineTotalGhs: product.priceGhs,
            category: product.category,
          ),
        ],
        shipping: saved.shipping,
        paymentMethods: saved.paymentMethods,
        createdAt: saved.createdAt,
      ),
    );

    await LocalStore.setUserJson(jsonEncode(seller.toJson()));
    final sellerOrders = await orders.sellerOrders();
    expect(sellerOrders.map((o) => o.id), contains(orderId));
  });
}
