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
}
