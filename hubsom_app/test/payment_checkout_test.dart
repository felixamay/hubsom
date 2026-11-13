import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/repositories/order_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_huber_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/services/payment_service.dart';
import 'package:hubsom_app/models/order.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-checkout');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  setUp(() async {
    CloudStore.useNetwork = false;
    await LocalStore.setString('localOrders', '[]');
    await LocalStore.setString('localShipments', '[]');
  });

  const items = [
    {
      'productId': 'p1',
      'sellerId': 'seller-1',
      'name': 'Wax print',
      'quantity': 1,
      'priceGhs': 80,
      'category': 'fashion',
    },
  ];
  const shipping = {
    'recipientName': 'Kojo Buyer',
    'phone': '0241111111',
    'line1': 'Kejetia Market',
    'city': 'Kumasi',
    'region': 'Ashanti',
  };

  test('API orderId is treated as success, not a second paid order', () async {
    final api = ApiClient(
      dio: _stubDio(
        statusCode: 200,
        body: {
          'orderId': 'ord_server',
          'currency': 'GHS',
          'subtotalGhs': 95,
          'status': 'pending_payment',
          'lines': [
            {
              'productId': 'p1',
              'sellerId': 'seller-1',
              'name': 'Wax print',
              'quantity': 1,
              'unitPriceGhs': 95,
              'lineTotalGhs': 95,
              'category': 'fashion',
            },
          ],
          'shipping': shipping,
          'createdAt': '2026-11-13T11:00:00.000Z',
        },
      ),
    );
    final result = await PaymentService(api).checkout(
      items: items,
      shipping: shipping,
      paymentMethods: const ['mtn-momo'],
    );

    expect(result['id'], 'ord_server');
    expect(result['orderId'], 'ord_server');
    expect(result['status'], 'pending_payment');
    expect(result['order']?['id'], 'ord_server');

    final stored = LocalHuberStore.listOrders();
    expect(stored, hasLength(1));
    expect(stored.single.id, 'ord_server');
    expect(stored.single.status, 'pending_payment');
    expect(stored.single.subtotalGhs, 95);
    expect(stored.any((o) => o.status == 'paid'), isFalse);
  });

  test('OrderRepository.checkout reads orderId the same way', () async {
    final api = ApiClient(
      dio: _stubDio(
        statusCode: 200,
        body: {
          'orderId': 'ord_repo',
          'subtotalGhs': 40,
          'status': 'pending_payment',
          'lines': const <Map<String, dynamic>>[],
          'createdAt': '2026-11-13T11:00:00.000Z',
        },
      ),
    );
    final order = await OrderRepository(api).checkout({
      'items': items,
      'shipping': shipping,
    });
    expect(order.id, 'ord_repo');
    expect(order.status, 'pending_payment');
    expect(LocalHuberStore.getOrder('ord_repo')?.status, 'pending_payment');
  });

  test('server 409 does not fabricate a paid local order', () async {
    final api = ApiClient(
      dio: _stubDio(
        statusCode: 409,
        body: {'error': 'Insufficient stock for Wax print'},
      ),
    );
    await expectLater(
      PaymentService(api).checkout(
        items: items,
        shipping: shipping,
        paymentMethods: const ['mtn-momo'],
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Insufficient stock'),
        ),
      ),
    );
    expect(LocalHuberStore.listOrders(), isEmpty);
  });

  test('offline fallback stays pending_payment, never paid', () async {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://checkout.test',
        responseType: ResponseType.plain,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              message: 'network down',
            ),
          );
        },
      ),
    );

    final result = await PaymentService(ApiClient(dio: dio)).checkout(
      items: items,
      shipping: shipping,
      paymentMethods: const ['mtn-momo'],
    );

    expect(result['status'], 'pending_payment');
    expect(result['order']?['status'], 'pending_payment');
    expect(LocalHuberStore.listOrders(), hasLength(1));
    expect(LocalHuberStore.listOrders().single.status, 'pending_payment');
  });

  test('Order.fromCheckoutPayload maps orderId onto id', () {
    final order = Order.fromCheckoutPayload({
      'orderId': 'ord_x',
      'subtotalGhs': 10,
      'status': 'pending_payment',
      'createdAt': '2026-11-13T11:00:00.000Z',
    });
    expect(order.id, 'ord_x');
    expect(Order.tryFromCheckoutPayload({'error': 'nope'}), isNull);
  });
}

Dio _stubDio({required int statusCode, required Object body}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://checkout.test',
      responseType: ResponseType.plain,
      validateStatus: (s) => s != null && s < 500,
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: statusCode,
            data: jsonEncode(body),
          ),
        );
      },
    ),
  );
  return dio;
}
