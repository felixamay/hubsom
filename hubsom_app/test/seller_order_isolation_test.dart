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
import 'package:hubsom_app/models/order.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

Order _paidOrder({
  required String id,
  required String sellerId,
  String buyerName = 'Kojo Buyer',
}) {
  return Order(
    id: id,
    subtotalGhs: 80,
    status: 'paid',
    buyerName: buyerName,
    lines: [
      OrderLine(
        productId: 'p-$id',
        sellerId: sellerId,
        name: 'Wax print',
        quantity: 1,
        unitPriceGhs: 80,
        lineTotalGhs: 80,
        category: 'fashion',
      ),
    ],
    shipping: const OrderShipping(
      recipientName: 'Kojo Buyer',
      phone: '0241111111',
      line1: '12 Spintex Rd',
      city: 'Accra',
      region: 'Greater Accra',
    ),
    createdAt: DateTime.now().toUtc().toIso8601String(),
  );
}

ApiClient _offlineApi() {
  return ApiClient(
    dio: Dio(
      BaseOptions(
        baseUrl: 'http://127.0.0.1:1',
        connectTimeout: const Duration(milliseconds: 20),
        receiveTimeout: const Duration(milliseconds: 20),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-seller-isolation');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  test('new seller without sellerId does not see another store paid order',
      () async {
    await LocalHuberStore.saveOrder(
      _paidOrder(id: 'ord_other', sellerId: 'seller-other'),
    );

    const newbie = HubsomUser(
      id: 'u-new',
      email: 'new-seller@hubsom.test',
      name: 'New Seller',
      role: 'seller',
    );
    await LocalStore.setUserJson(jsonEncode(newbie.toJson()));
    await LocalStore.setSessionToken('tok');

    final orders = await OrderRepository(_offlineApi()).sellerOrders();
    expect(orders, isEmpty);

    final session = HubsomUser.fromJson(
      Map<String, dynamic>.from(jsonDecode(LocalStore.userJson!) as Map),
    );
    expect(session.sellerId, 'seller-u-new');
  });

  test('new seller cannot consolidate or cancel another store paid order',
      () async {
    final foreign = _paidOrder(id: 'ord_foreign', sellerId: 'seller-other');
    await LocalHuberStore.saveOrder(foreign);

    const newbie = HubsomUser(
      id: 'u-new',
      email: 'new-seller@hubsom.test',
      name: 'New Seller',
      role: 'seller',
    );
    await LocalStore.setUserJson(jsonEncode(newbie.toJson()));
    await LocalStore.setSessionToken('tok');

    final repo = OrderRepository(_offlineApi());
    expect(
      () => repo.createShipment({
        'orderIds': [foreign.id],
      }),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('not from your store'),
        ),
      ),
    );
    expect(
      () => repo.updateOrder(foreign.id, {'status': 'cancelled'}),
      throwsA(isA<StateError>()),
    );
    expect(LocalHuberStore.getOrder(foreign.id)?.status, 'paid');
  });

  test('seller still sees and consolidates their own paid order', () async {
    const seller = HubsomUser(
      id: 'u-own',
      email: 'own@hubsom.test',
      name: 'Own Seller',
      role: 'seller',
      sellerId: 'seller-u-own',
    );
    await LocalStore.setUserJson(jsonEncode(seller.toJson()));
    await LocalStore.setSessionToken('tok');

    final mine = _paidOrder(id: 'ord_mine', sellerId: 'seller-u-own');
    await LocalHuberStore.saveOrder(
      _paidOrder(id: 'ord_other', sellerId: 'seller-other'),
    );
    await LocalHuberStore.saveOrder(mine);

    final repo = OrderRepository(_offlineApi());
    final orders = await repo.sellerOrders();
    expect(orders.map((o) => o.id), ['ord_mine']);

    final shipment = await repo.createShipment({
      'orderIds': [mine.id],
    });
    expect(shipment.sellerId, 'seller-u-own');
    expect(shipment.orderIds, [mine.id]);
  });
}
