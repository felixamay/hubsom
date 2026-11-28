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
    final dir = Directory.systemTemp.createTempSync('hubsom-huber-idor');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  test('a second Huber cannot complete another rider’s active delivery', () async {
    final assigned = await _onlineHuber(
      id: 'u-assigned',
      email: 'ama@hubsom.test',
      name: 'Ama Rider',
      huberId: 'huber-assigned',
    );
    final interloper = await _onlineHuber(
      id: 'u-other',
      email: 'kojo@hubsom.test',
      name: 'Kojo Rider',
      huberId: 'huber-other',
    );

    final order = Order(
      id: 'ord_idor_1',
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
        recipientName: 'Buyer',
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
    await LocalHuberStore.dispatchToHubers(shipment);

    final offer = LocalHuberStore.openOffersForDriver(assigned.id).first;
    final delivery = await LocalHuberStore.acceptOffer(
      offerId: offer.id,
      driver: LocalHuberStore.profileById(assigned.id)!,
    );

    final assignedToOther = isA<StateError>().having(
      (e) => e.message,
      'message',
      contains('another rider'),
    );
    await expectLater(
      LocalHuberStore.advanceDelivery(
        delivery.id,
        actorHuberId: interloper.id,
      ),
      throwsA(assignedToOther),
    );
    await expectLater(
      LocalHuberStore.completeWithPod(
        delivery.id,
        actorHuberId: interloper.id,
      ),
      throwsA(assignedToOther),
    );
    // Same job discovered via the shipment id in a copied /huber/delivery/:id URL.
    await expectLater(
      LocalHuberStore.advanceDelivery(
        shipment.id,
        actorHuberId: interloper.id,
      ),
      throwsA(assignedToOther),
    );
    await expectLater(
      LocalHuberStore.completeWithPod(
        shipment.id,
        actorHuberId: interloper.id,
      ),
      throwsA(assignedToOther),
    );

    expect(LocalHuberStore.deliveryById(delivery.id)?.status, 'accepted');
    expect(LocalHuberStore.getShipment(shipment.id)?.status, 'assigned');
    expect(LocalHuberStore.getOrder(order.id)?.status, 'processing');
    expect(LocalHuberStore.profileById(assigned.id)!.walletBalanceGhs, 0);
    expect(LocalHuberStore.profileById(interloper.id)!.walletBalanceGhs, 0);

    final done = await LocalHuberStore.completeWithPod(
      delivery.id,
      actorHuberId: assigned.id,
    );
    expect(done.status, 'delivered');
    expect(LocalHuberStore.getShipment(shipment.id)?.status, 'delivered');
    expect(LocalHuberStore.getOrder(order.id)?.status, 'delivered');
    expect(
      LocalHuberStore.profileById(assigned.id)!.walletBalanceGhs,
      greaterThan(0),
    );
    expect(LocalHuberStore.profileById(interloper.id)!.walletBalanceGhs, 0);
  });
}

Future<HuberProfile> _onlineHuber({
  required String id,
  required String email,
  required String name,
  required String huberId,
}) async {
  final user = HubsomUser(
    id: id,
    email: email,
    name: name,
    role: 'huber',
    huberId: huberId,
    phone: '0240000000',
  );
  final profile = await LocalHuberStore.ensureProfileForUser(
    user,
    details: const HuberSignUpDetails(phone: '0240000000'),
  );
  await LocalHuberStore.verifyIdentity(
    huberId: profile.id,
    idType: 'GHANA_CARD',
    idNumber: 'GHA-1234-5678',
  );
  await LocalHuberStore.setOnline(profile.id, true);
  return LocalHuberStore.profileById(profile.id)!;
}
