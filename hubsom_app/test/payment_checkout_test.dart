import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_huber_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/services/payment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-checkout');
    Hive.init(dir.path);
    await LocalStore.init();
    await LocalStore.remove('localOrders');
  });

  test('orderJsonFromCheckoutResponse accepts orderId from the API', () {
    final mapped = PaymentService.orderJsonFromCheckoutResponse({
      'orderId': 'ord_api_1',
      'status': 'pending_payment',
      'subtotalGhs': 40,
      'lines': [
        {
          'productId': 'p1',
          'name': 'Wax print',
          'quantity': 1,
          'unitPriceGhs': 40,
          'lineTotalGhs': 40,
          'category': 'fashion',
        },
      ],
    });
    expect(mapped, isNotNull);
    expect(mapped!['id'], 'ord_api_1');
    expect(mapped['status'], 'pending_payment');
  });

  test('API 409 insufficient stock does not write a paid local order', () async {
    final payments = PaymentService(
      ApiClient(dio: _stubDio(409, {'error': 'Insufficient stock for Wax print'})),
    );

    await expectLater(
      payments.checkout(
        items: const [
          {
            'productId': 'p1',
            'name': 'Wax print',
            'quantity': 1,
            'priceGhs': 40,
          },
        ],
        shipping: const {
          'recipientName': 'Ama',
          'phone': '0240000000',
          'line1': '12 Spintex',
          'city': 'Accra',
          'region': 'Greater Accra',
        },
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

  test('API success with orderId keeps pending_payment instead of minting paid',
      () async {
    final payments = PaymentService(
      ApiClient(
        dio: _stubDio(200, {
          'orderId': 'ord_api_9',
          'status': 'pending_payment',
          'subtotalGhs': 40,
          'currency': 'GHS',
          'lines': [
            {
              'productId': 'p1',
              'sellerId': 'seller-1',
              'name': 'Wax print',
              'quantity': 1,
              'unitPriceGhs': 40,
              'lineTotalGhs': 40,
              'category': 'fashion',
            },
          ],
          'shipping': {
            'recipientName': 'Ama',
            'phone': '0240000000',
            'line1': '12 Spintex',
            'city': 'Accra',
            'region': 'Greater Accra',
          },
          'createdAt': '2026-10-31T11:00:00.000Z',
        }),
      ),
    );

    final res = await payments.checkout(
      items: const [
        {
          'productId': 'p1',
          'name': 'Wax print',
          'quantity': 1,
          'priceGhs': 40,
        },
      ],
      shipping: const {
        'recipientName': 'Ama',
        'phone': '0240000000',
        'line1': '12 Spintex',
        'city': 'Accra',
        'region': 'Greater Accra',
      },
      paymentMethods: const ['mtn-momo'],
    );

    expect(res['id'], 'ord_api_9');
    expect(res['order']?['id'], 'ord_api_9');
    expect(res['order']?['status'], 'pending_payment');
    final saved = LocalHuberStore.listOrders();
    expect(saved, hasLength(1));
    expect(saved.single.id, 'ord_api_9');
    expect(saved.single.status, 'pending_payment');
  });

  test('SPA HTML fallback still creates a local order when Hosting has no API',
      () async {
    final payments = PaymentService(
      ApiClient(dio: _stubDio(200, '<!doctype html><html></html>')),
    );

    final res = await payments.checkout(
      items: const [
        {
          'productId': 'p1',
          'name': 'Wax print',
          'quantity': 1,
          'priceGhs': 40,
        },
      ],
      shipping: const {
        'recipientName': 'Ama',
        'phone': '0240000000',
        'line1': '12 Spintex',
        'city': 'Accra',
        'region': 'Greater Accra',
      },
      paymentMethods: const ['mtn-momo'],
    );

    expect(res['order']?['status'], 'paid');
    expect(LocalHuberStore.listOrders(), hasLength(1));
  });
}

Dio _stubDio(int status, Object body) {
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
            statusCode: status,
            data: body is String ? body : jsonEncode(body),
          ),
        );
      },
    ),
  );
  return dio;
}
