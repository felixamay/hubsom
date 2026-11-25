import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/order_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_huber_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/huber.dart';
import 'package:hubsom_app/models/order.dart';
import 'package:hubsom_app/models/shipment.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-order-status');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  test('seller order status + ship after huber accept + rider delivered', () async {
    final driverUser = HubsomUser(
      id: 'u1',
      email: 'rider@hubsom.test',
      name: 'Ama Rider',
      role: 'huber',
      huberId: 'huber-u1',
      phone: '0240000000',
    );
    final profile = await LocalHuberStore.ensureProfileForUser(
      driverUser,
      details: const HuberSignUpDetails(phone: '0240000000'),
    );
    await LocalHuberStore.verifyIdentity(
      huberId: profile.id,
      idType: 'GHANA_CARD',
      idNumber: 'GHA-1234-5678',
    );
    await LocalHuberStore.setOnline(profile.id, true);

    final order = Order(
      id: 'ord_ship_1',
      subtotalGhs: 80,
      status: 'paid',
      lines: const [
        OrderLine(
          productId: 'p1',
          sellerId: 'seller-1',
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
        location: GeoLocation(latitude: 5.63, longitude: -0.17),
      ),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    await LocalHuberStore.saveOrder(order);

    await LocalHuberStore.updateOrderStatus(order.id, 'processing');
    expect(LocalHuberStore.getOrder(order.id)?.status, 'processing');

    final shipment = await LocalHuberStore.createShipmentFromOrders(
      orderIds: [order.id],
      sellerId: 'seller-1',
      createdByUserId: 'seller-1',
    );
    expect(shipment.status, 'ready');
    expect(LocalHuberStore.getOrder(order.id)?.status, 'processing');

    final dispatched = await LocalHuberStore.dispatchToHubers(shipment);
    expect(dispatched.shipment.status, 'offering');

    final offer = LocalHuberStore.openOffersForDriver(profile.id).first;
    await LocalHuberStore.acceptOffer(
      offerId: offer.id,
      driver: LocalHuberStore.profileById(profile.id)!,
    );
    expect(LocalHuberStore.getShipment(shipment.id)?.status, 'assigned');
    expect(LocalHuberStore.getOrder(order.id)?.status, 'processing');

    final shipped = await LocalHuberStore.markShipmentShipped(shipment.id);
    expect(shipped.status, 'shipped');
    expect(LocalHuberStore.getOrder(order.id)?.status, 'shipped');

    final delivery = LocalHuberStore.listDeliveries()
        .firstWhere((d) => d.shipmentId == shipment.id);
    final done = await LocalHuberStore.completeWithPod(delivery.id);
    expect(done.status, 'delivered');
    expect(LocalHuberStore.getShipment(shipment.id)?.status, 'delivered');
    expect(LocalHuberStore.getOrder(order.id)?.status, 'delivered');
  });

  test('another seller cannot list, ship, or re-offer a competitor shipment',
      () async {
    final assigned = await _seedAssignedShipment(suffix: 'xstore');
    expect(assigned.shipment.status, 'assigned');

    expect(
      () => LocalHuberStore.markShipmentShipped(
        assigned.shipment.id,
        sellerId: 'seller-other',
        actorUserId: 'u-other',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Not your shipment'),
        ),
      ),
    );
    expect(
      LocalHuberStore.getShipment(assigned.shipment.id)?.status,
      'assigned',
    );
    expect(LocalHuberStore.getOrder(assigned.order.id)?.status, 'processing');

    expect(
      () => LocalHuberStore.dispatchToHubers(
        assigned.shipment,
        sellerId: 'seller-other',
        actorUserId: 'u-other',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Not your shipment'),
        ),
      ),
    );
    expect(
      LocalHuberStore.getShipment(assigned.shipment.id)?.status,
      'assigned',
    );

    await LocalStore.setUserJson(
      jsonEncode({
        'id': 'u-other',
        'email': 'other@hubsom.test',
        'name': 'Other Store',
        'role': 'seller',
        'sellerId': 'seller-other',
      }),
    );
    final repo = OrderRepository(_offlineClient());
    final listed = await repo.listShipments();
    expect(listed.map((s) => s.id), isNot(contains(assigned.shipment.id)));

    await expectLater(
      repo.markShipmentShipped(assigned.shipment.id),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Not your shipment'),
        ),
      ),
    );
    await expectLater(
      repo.offerToHubers(assigned.shipment.id),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Not your shipment'),
        ),
      ),
    );
    await expectLater(
      repo.updateShipment(assigned.shipment.id, {'status': 'delivered'}),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Not your shipment'),
        ),
      ),
    );
    expect(
      LocalHuberStore.getShipment(assigned.shipment.id)?.status,
      'assigned',
    );

    await LocalStore.setUserJson(
      jsonEncode({
        'id': 'seller-xstore',
        'email': 'owner@hubsom.test',
        'name': 'Owner Store',
        'role': 'seller',
        'sellerId': 'seller-xstore',
      }),
    );
    final own = OrderRepository(_offlineClient());
    final mine = await own.listShipments();
    expect(mine.map((s) => s.id), contains(assigned.shipment.id));
    final shipped = await own.markShipmentShipped(assigned.shipment.id);
    expect(shipped.status, 'shipped');
    expect(LocalHuberStore.getOrder(assigned.order.id)?.status, 'shipped');
  });
}

ApiClient _offlineClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://127.0.0.1',
      connectTimeout: const Duration(milliseconds: 50),
      receiveTimeout: const Duration(milliseconds: 50),
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'offline',
          ),
        );
      },
    ),
  );
  return ApiClient(dio: dio);
}

class _AssignedShipment {
  const _AssignedShipment({
    required this.order,
    required this.shipment,
  });
  final Order order;
  final Shipment shipment;
}

Future<_AssignedShipment> _seedAssignedShipment({String suffix = 'own'}) async {
  final driverUser = HubsomUser(
    id: 'u-ship-$suffix',
    email: 'rider-$suffix@hubsom.test',
    name: 'Ama Rider',
    role: 'huber',
    huberId: 'huber-ship-$suffix',
    phone: '0240000000',
  );
  final profile = await LocalHuberStore.ensureProfileForUser(
    driverUser,
    details: const HuberSignUpDetails(phone: '0240000000'),
  );
  await LocalHuberStore.verifyIdentity(
    huberId: profile.id,
    idType: 'GHANA_CARD',
    idNumber: 'GHA-1234-5678',
  );
  await LocalHuberStore.setOnline(profile.id, true);

  final order = Order(
    id: 'ord_ship_$suffix',
    subtotalGhs: 80,
    status: 'paid',
    lines: [
      OrderLine(
        productId: 'p-$suffix',
        sellerId: 'seller-$suffix',
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
      location: GeoLocation(latitude: 5.63, longitude: -0.17),
    ),
    createdAt: DateTime.now().toUtc().toIso8601String(),
  );
  await LocalHuberStore.saveOrder(order);
  final shipment = await LocalHuberStore.createShipmentFromOrders(
    orderIds: [order.id],
    sellerId: 'seller-$suffix',
    createdByUserId: 'seller-$suffix',
  );
  final dispatched = await LocalHuberStore.dispatchToHubers(shipment);
  final offer = LocalHuberStore.openOffersForDriver(profile.id).first;
  await LocalHuberStore.acceptOffer(
    offerId: offer.id,
    driver: LocalHuberStore.profileById(profile.id)!,
  );
  return _AssignedShipment(
    order: order,
    shipment: LocalHuberStore.getShipment(dispatched.shipment.id)!,
  );
}
