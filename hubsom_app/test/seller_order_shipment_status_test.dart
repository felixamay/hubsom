import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_huber_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/huber.dart';
import 'package:hubsom_app/models/order.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
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
}
