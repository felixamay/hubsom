import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_huber_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/huber.dart';
import 'package:hubsom_app/models/order.dart';
import 'package:hubsom_app/models/shipment.dart';
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

Order _paidOrder(String id, {String status = 'paid'}) {
  return Order(
    id: id,
    subtotalGhs: 80,
    status: status,
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    CloudStore.useNetwork = false;
    LocalHuberStore.debugIncomingShipments = null;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-dup-ship');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  test('consolidating the same paid order twice does not create a second shipment',
      () async {
    await LocalHuberStore.saveOrder(_paidOrder('ord_once'));
    final first = await LocalHuberStore.createShipmentFromOrders(
      orderIds: const ['ord_once'],
      sellerId: 'seller-1',
      createdByUserId: 'seller-1',
      offeredFeeGhs: 20,
    );
    expect(first.status, 'ready');
    expect(LocalHuberStore.getOrder('ord_once')?.status, 'processing');
    expect(LocalHuberStore.orderHasActiveShipment('ord_once'), isTrue);

    await expectLater(
      LocalHuberStore.createShipmentFromOrders(
        orderIds: const ['ord_once'],
        sellerId: 'seller-1',
        createdByUserId: 'seller-1',
        offeredFeeGhs: 20,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already on a shipment'),
        ),
      ),
    );
    expect(
      LocalHuberStore.listShipments().where((s) => s.orderIds.contains('ord_once')),
      hasLength(1),
    );
  });

  test('a later paid order can still be consolidated after the first shipment',
      () async {
    await LocalHuberStore.saveOrder(_paidOrder('ord_a'));
    await LocalHuberStore.createShipmentFromOrders(
      orderIds: const ['ord_a'],
      sellerId: 'seller-1',
      createdByUserId: 'seller-1',
      offeredFeeGhs: 20,
    );
    await LocalHuberStore.saveOrder(_paidOrder('ord_b'));

    final second = await LocalHuberStore.createShipmentFromOrders(
      orderIds: const ['ord_b'],
      sellerId: 'seller-1',
      createdByUserId: 'seller-1',
      offeredFeeGhs: 18,
    );
    expect(second.orderIds, ['ord_b']);
    expect(
      LocalHuberStore.listShipments()
          .where((s) => s.occupiesOrders && s.orderIds.contains('ord_a')),
      hasLength(1),
    );
    expect(
      LocalHuberStore.listShipments()
          .where((s) => s.occupiesOrders && s.orderIds.contains('ord_b')),
      hasLength(1),
    );
  });

  test('cancelling the first shipment frees the order to consolidate again',
      () async {
    await LocalHuberStore.saveOrder(_paidOrder('ord_retry'));
    final first = await LocalHuberStore.createShipmentFromOrders(
      orderIds: const ['ord_retry'],
      sellerId: 'seller-1',
      createdByUserId: 'seller-1',
      offeredFeeGhs: 20,
    );
    await LocalHuberStore.saveShipment(
      first.copyWith(
        status: 'cancelled',
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    expect(LocalHuberStore.orderHasActiveShipment('ord_retry'), isFalse);

    final retry = await LocalHuberStore.createShipmentFromOrders(
      orderIds: const ['ord_retry'],
      sellerId: 'seller-1',
      createdByUserId: 'seller-1',
      offeredFeeGhs: 22,
    );
    expect(retry.id, isNot(first.id));
    expect(retry.orderIds, ['ord_retry']);
  });

  test('two riders cannot both get paid for duplicate shipments of one order',
      () async {
    final first = await _onlineRider(
      id: 'dup1',
      name: 'Ama Rider',
      email: 'ama-dup@hubsom.test',
    );
    final second = await _onlineRider(
      id: 'dup2',
      name: 'Kojo Rider',
      email: 'kojo-dup@hubsom.test',
    );
    await LocalHuberStore.saveOrder(_paidOrder('ord_shared'));
    final shipment = await LocalHuberStore.createShipmentFromOrders(
      orderIds: const ['ord_shared'],
      sellerId: 'seller-1',
      createdByUserId: 'seller-1',
      offeredFeeGhs: 25,
    );

    await expectLater(
      LocalHuberStore.createShipmentFromOrders(
        orderIds: const ['ord_shared'],
        sellerId: 'seller-1',
        createdByUserId: 'seller-1',
        offeredFeeGhs: 25,
      ),
      throwsA(isA<StateError>()),
    );

    await LocalHuberStore.dispatchToHubers(shipment);
    final offer = LocalHuberStore.openOffersForDriver(first.id).first;
    final delivery = await LocalHuberStore.acceptOffer(
      offerId: offer.id,
      driver: LocalHuberStore.profileById(first.id)!,
    );
    await LocalHuberStore.completeWithPod(delivery.id);

    expect(
      LocalHuberStore.listShipments()
          .where((s) => s.occupiesOrders && s.orderIds.contains('ord_shared')),
      hasLength(1),
    );
    expect(
      LocalHuberStore.listDeliveries().where((d) => d.shipmentId == shipment.id),
      hasLength(1),
    );
    expect(LocalHuberStore.profileById(first.id)!.walletBalanceGhs, 25);
    expect(LocalHuberStore.profileById(second.id)!.walletBalanceGhs, 0);
  });

  test('cannot consolidate an order another device already put on a shipment',
      () async {
    await LocalHuberStore.saveOrder(_paidOrder('ord_phone'));
    expect(
      LocalHuberStore.listShipments()
          .where((s) => s.orderIds.contains('ord_phone')),
      isEmpty,
    );

    LocalHuberStore.debugIncomingShipments = [
      Shipment(
        id: 'shp_phone',
        sellerId: 'seller-1',
        createdByUserId: 'seller-1',
        orderIds: const ['ord_phone'],
        items: const [
          ShipmentItem(
            orderId: 'ord_phone',
            productId: 'p1',
            name: 'Wax print',
            quantity: 1,
            lineTotalGhs: 80,
          ),
        ],
        destination: const OrderShipping(
          recipientName: 'Buyer',
          phone: '0241111111',
          line1: '12 Spintex Rd',
          city: 'Accra',
          region: 'Greater Accra',
        ),
        status: 'ready',
        offeredFeeGhs: 20,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      ).toJson(),
    ];

    await expectLater(
      LocalHuberStore.createShipmentFromOrders(
        orderIds: const ['ord_phone'],
        sellerId: 'seller-1',
        createdByUserId: 'seller-1',
        offeredFeeGhs: 20,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already on a shipment'),
        ),
      ),
    );
    expect(
      LocalHuberStore.listShipments()
          .where((s) => s.occupiesOrders && s.orderIds.contains('ord_phone'))
          .map((s) => s.id),
      ['shp_phone'],
    );
  });

  test('stale cloud hydrate cannot drop a just-consolidated shipment', () async {
    await LocalHuberStore.saveOrder(_paidOrder('ord_hydrate'));
    final created = await LocalHuberStore.createShipmentFromOrders(
      orderIds: const ['ord_hydrate'],
      sellerId: 'seller-1',
      createdByUserId: 'seller-1',
      offeredFeeGhs: 20,
    );
    expect(LocalHuberStore.orderHasActiveShipment('ord_hydrate'), isTrue);

    // Same replace hydrateLocalCache used to do: cloud has older lots only.
    final older = created.toJson()
      ..['id'] = 'shp_old'
      ..['orderIds'] = ['ord_old']
      ..['status'] = 'delivered';
    final merged = CloudStore.mergeShipmentDocs(
      localKey: 'localShipments',
      incoming: [older],
    );
    await LocalStore.setString('localShipments', jsonEncode(merged));

    expect(LocalHuberStore.getShipment(created.id)?.status, 'ready');
    expect(LocalHuberStore.orderHasActiveShipment('ord_hydrate'), isTrue);
    await expectLater(
      LocalHuberStore.createShipmentFromOrders(
        orderIds: const ['ord_hydrate'],
        sellerId: 'seller-1',
        createdByUserId: 'seller-1',
        offeredFeeGhs: 20,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already on a shipment'),
        ),
      ),
    );
  });
}
