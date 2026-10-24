import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/auth/auth_routes.dart';
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
    final dir = Directory.systemTemp.createTempSync('hubsom-hive');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  test('homeForUser sends Huber accounts to /huber', () {
    expect(AuthRoutes.homeForUser('huber'), '/huber');
    expect(AuthRoutes.homeForUser('driver'), '/huber');
    expect(AuthRoutes.homeForUser('buyer'), '/account');
    expect(
      AuthRoutes.homeForUser('huber', callback: '/account'),
      '/huber',
    );
    expect(
      AuthRoutes.homeForUser('huber', callback: '/checkout'),
      '/checkout',
    );
    expect(AuthRoutes.isHuberRole('huber'), isTrue);
    expect(AuthRoutes.requiresHuber('/huber/hub'), isTrue);
    expect(AuthRoutes.requiresHuber('/account'), isFalse);
  });

  test('dispatch, accept, and complete stay on the same Hubsom account', () async {
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
      id: 'ord_1',
      subtotalGhs: 80,
      status: 'paid',
      lines: const [
        OrderLine(
          productId: 'p1',
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
      sellerId: 'seller-1',
      createdByUserId: 'seller-1',
    );
    final dispatched = await LocalHuberStore.dispatchToHubers(shipment);
    expect(dispatched.offers, isNotEmpty);
    expect(dispatched.offers.first.huberId, profile.id);

    final offer = LocalHuberStore.openOffersForDriver(profile.id).first;
    final delivery = await LocalHuberStore.acceptOffer(
      offerId: offer.id,
      driver: LocalHuberStore.profileById(profile.id)!,
    );
    expect(delivery.shipmentId, shipment.id);
    expect(LocalHuberStore.getShipment(shipment.id)?.status, 'assigned');

    final done = await LocalHuberStore.completeWithPod(delivery.id);
    expect(done.status, 'delivered');
    expect(LocalHuberStore.getShipment(shipment.id)?.status, 'delivered');
    expect(LocalHuberStore.profileById(profile.id)!.walletBalanceGhs, greaterThan(0));
  });
}
