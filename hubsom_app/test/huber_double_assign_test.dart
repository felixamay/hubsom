import 'dart:convert';
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

Future<HuberProfile> _onlineRider({
  required String id,
  required String name,
  required String email,
}) async {
  final user = HubsomUser(
    id: id,
    email: email,
    name: name,
    role: 'huber',
    huberId: 'huber-$id',
    phone: '024000000$id',
  );
  final profile = await LocalHuberStore.ensureProfileForUser(
    user,
    details: HuberSignUpDetails(phone: user.phone ?? ''),
  );
  await LocalHuberStore.verifyIdentity(
    huberId: profile.id,
    idType: 'GHANA_CARD',
    idNumber: 'GHA-$id-0000',
  );
  return LocalHuberStore.setOnline(profile.id, true);
}

Future<void> _reopenOffer(String offerId) async {
  final rows = LocalHuberStore.listOffers()
      .map((o) => o.id == offerId ? o.copyWith(status: 'sent') : o)
      .map((o) => o.toJson())
      .toList();
  await LocalStore.setString('huberOffers', jsonEncode(rows));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    CloudStore.useNetwork = false;
    LocalHuberStore.lastSyncedByCollection.clear();
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-huber-assign');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  test('second rider cannot take a shipment another rider already accepted', () async {
    final first = await _onlineRider(
      id: 'u1',
      name: 'Ama Rider',
      email: 'ama@hubsom.test',
    );
    final second = await _onlineRider(
      id: 'u2',
      name: 'Kojo Rider',
      email: 'kojo@hubsom.test',
    );

    final order = Order(
      id: 'ord_shared_1',
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
      offeredFeeGhs: 25,
    );
    await LocalHuberStore.dispatchToHubers(shipment);

    final firstOffer = LocalHuberStore.openOffersForDriver(first.id).first;
    final secondOffer = LocalHuberStore.openOffersForDriver(second.id).first;

    final delivery = await LocalHuberStore.acceptOffer(
      offerId: firstOffer.id,
      driver: LocalHuberStore.profileById(first.id)!,
    );
    expect(delivery.huberId, first.id);
    expect(LocalHuberStore.getShipment(shipment.id)?.assignedHuberId, first.id);
    expect(
      LocalHuberStore.listDeliveries().where((d) => d.shipmentId == shipment.id),
      hasLength(1),
    );

    // The second phone still shows the offer as open until it hydrates.
    await _reopenOffer(secondOffer.id);
    expect(LocalHuberStore.openOffersForDriver(second.id), isNotEmpty);

    await expectLater(
      LocalHuberStore.acceptOffer(
        offerId: secondOffer.id,
        driver: LocalHuberStore.profileById(second.id)!,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Another rider already took this delivery'),
        ),
      ),
    );
    expect(
      LocalHuberStore.listDeliveries().where((d) => d.shipmentId == shipment.id),
      hasLength(1),
    );
    expect(LocalHuberStore.getShipment(shipment.id)?.assignedHuberId, first.id);
    expect(LocalHuberStore.profileById(second.id)!.walletBalanceGhs, 0);
  });

  test('completing a delivery twice does not pay the rider twice', () async {
    final rider = await _onlineRider(
      id: 'u3',
      name: 'Ama Rider',
      email: 'ama2@hubsom.test',
    );
    final order = Order(
      id: 'ord_pay_once',
      subtotalGhs: 40,
      status: 'paid',
      lines: const [
        OrderLine(
          productId: 'p2',
          sellerId: 'seller-1',
          name: 'Shea',
          quantity: 1,
          unitPriceGhs: 40,
          lineTotalGhs: 40,
          category: 'beauty',
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
      offeredFeeGhs: 15,
    );
    await LocalHuberStore.dispatchToHubers(shipment);
    final offer = LocalHuberStore.openOffersForDriver(rider.id).first;
    final delivery = await LocalHuberStore.acceptOffer(
      offerId: offer.id,
      driver: LocalHuberStore.profileById(rider.id)!,
    );

    final first = await LocalHuberStore.completeWithPod(delivery.id);
    expect(first.status, 'delivered');
    final paid = LocalHuberStore.profileById(rider.id)!.walletBalanceGhs;
    expect(paid, greaterThan(0));

    final again = await LocalHuberStore.advanceDelivery(delivery.id);
    expect(again.status, 'delivered');
    expect(LocalHuberStore.profileById(rider.id)!.walletBalanceGhs, paid);
    expect(LocalHuberStore.profileById(rider.id)!.completedCount, 1);
  });

  test('stale cloud hydrate cannot pay a rider twice after proof of delivery',
      () async {
    final rider = await _onlineRider(
      id: 'u4',
      name: 'Ama Rider',
      email: 'ama3@hubsom.test',
    );
    final order = Order(
      id: 'ord_hydrate_pay',
      subtotalGhs: 40,
      status: 'paid',
      lines: const [
        OrderLine(
          productId: 'p3',
          sellerId: 'seller-1',
          name: 'Shea',
          quantity: 1,
          unitPriceGhs: 40,
          lineTotalGhs: 40,
          category: 'beauty',
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
      offeredFeeGhs: 15,
    );
    await LocalHuberStore.dispatchToHubers(shipment);
    final offer = LocalHuberStore.openOffersForDriver(rider.id).first;
    final delivery = await LocalHuberStore.acceptOffer(
      offerId: offer.id,
      driver: LocalHuberStore.profileById(rider.id)!,
    );
    final acceptedDelivery = Map<String, dynamic>.from(delivery.toJson());
    final acceptedProfile =
        Map<String, dynamic>.from(LocalHuberStore.profileById(rider.id)!.toJson());

    final done = await LocalHuberStore.completeWithPod(delivery.id);
    expect(done.status, 'delivered');
    final paid = LocalHuberStore.profileById(rider.id)!.walletBalanceGhs;
    expect(paid, 15);

    // Same replace hydrateLocalCache used to do: cloud still has accepted
    // and a pre-drop wallet because the complete upsert had not landed.
    final mergedDeliveries = CloudStore.mergeDeliveryDocs(
      localKey: 'huberDeliveries',
      incoming: [acceptedDelivery],
    );
    await LocalStore.setString('huberDeliveries', jsonEncode(mergedDeliveries));
    final mergedProfiles = CloudStore.mergeHuberProfileDocs(
      localKey: 'huberProfiles',
      incoming: [acceptedProfile],
    );
    await LocalStore.setString('huberProfiles', jsonEncode(mergedProfiles));

    expect(LocalHuberStore.deliveryById(delivery.id)?.status, 'delivered');
    expect(LocalHuberStore.profileById(rider.id)!.walletBalanceGhs, paid);

    final again = await LocalHuberStore.completeWithPod(delivery.id);
    expect(again.status, 'delivered');
    expect(LocalHuberStore.profileById(rider.id)!.walletBalanceGhs, paid);
    expect(LocalHuberStore.profileById(rider.id)!.completedCount, 1);
  });

  test('proof of delivery does not upsert another rider stale job to cloud',
      () async {
    final first = await _onlineRider(
      id: 'u5',
      name: 'Ama Rider',
      email: 'ama5@hubsom.test',
    );
    final second = await _onlineRider(
      id: 'u6',
      name: 'Kojo Rider',
      email: 'kojo6@hubsom.test',
    );

    Future<Order> paidOrder(String id) => LocalHuberStore.saveOrder(
          Order(
            id: id,
            subtotalGhs: 40,
            status: 'paid',
            lines: const [
              OrderLine(
                productId: 'p-writeback',
                sellerId: 'seller-1',
                name: 'Shea',
                quantity: 1,
                unitPriceGhs: 40,
                lineTotalGhs: 40,
                category: 'beauty',
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
          ),
        );

    await paidOrder('ord_writeback_a');
    await paidOrder('ord_writeback_b');
    final shipmentA = await LocalHuberStore.createShipmentFromOrders(
      orderIds: const ['ord_writeback_a'],
      sellerId: 'seller-1',
      createdByUserId: 'seller-1',
      offeredFeeGhs: 15,
    );
    final shipmentB = await LocalHuberStore.createShipmentFromOrders(
      orderIds: const ['ord_writeback_b'],
      sellerId: 'seller-1',
      createdByUserId: 'seller-1',
      offeredFeeGhs: 18,
    );
    await LocalHuberStore.dispatchToHubers(shipmentA);
    await LocalHuberStore.dispatchToHubers(shipmentB);

    final deliveryA = await LocalHuberStore.acceptOffer(
      offerId: LocalHuberStore.openOffersForDriver(first.id)
          .firstWhere((o) => o.shipmentId == shipmentA.id)
          .id,
      driver: LocalHuberStore.profileById(first.id)!,
    );
    final deliveryB = await LocalHuberStore.acceptOffer(
      offerId: LocalHuberStore.openOffersForDriver(second.id)
          .firstWhere((o) => o.shipmentId == shipmentB.id)
          .id,
      driver: LocalHuberStore.profileById(second.id)!,
    );

    final done = await LocalHuberStore.completeWithPod(deliveryA.id);
    expect(done.status, 'delivered');
    expect(LocalHuberStore.profileById(first.id)!.walletBalanceGhs, 15);

    final syncedDeliveries =
        LocalHuberStore.lastSyncedByCollection[CloudStore.deliveries] ??
            const [];
    expect(syncedDeliveries, hasLength(1));
    expect(syncedDeliveries.single['id'], deliveryA.id);
    expect(syncedDeliveries.single['status'], 'delivered');
    expect(
      syncedDeliveries.any((e) => e['id'] == deliveryB.id),
      isFalse,
    );

    final syncedProfiles =
        LocalHuberStore.lastSyncedByCollection[CloudStore.hubers] ?? const [];
    expect(syncedProfiles, hasLength(1));
    expect(syncedProfiles.single['id'], first.id);
    expect(syncedProfiles.single['walletBalanceGhs'], 15);
    expect(
      syncedProfiles.any((e) => e['id'] == second.id),
      isFalse,
    );

    // Kojo's phone still has Ama's job as accepted (cloud write from Ama
    // had not landed). His own advance must not push that stale POD.
    final staleA = deliveryA.copyWith(status: 'accepted');
    await LocalStore.setString(
      'huberDeliveries',
      jsonEncode([
        staleA.toJson(),
        LocalHuberStore.deliveryById(deliveryB.id)!.toJson(),
      ]),
    );
    await LocalHuberStore.advanceDelivery(deliveryB.id);

    final afterB =
        LocalHuberStore.lastSyncedByCollection[CloudStore.deliveries] ??
            const [];
    expect(afterB, hasLength(1));
    expect(afterB.single['id'], deliveryB.id);
    expect(
      afterB.any((e) => e['id'] == deliveryA.id),
      isFalse,
    );
  });
}
