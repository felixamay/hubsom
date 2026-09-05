import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/ghana_places.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_huber_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/huber.dart';
import 'package:hubsom_app/models/order.dart';
import 'package:hubsom_app/models/seller.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-pickup-km');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  test('Kumasi store pickup is farther than Accra for an Accra rider', () async {
    final kumasi = GhanaPlaces.resolve(city: 'Kumasi', region: 'Ashanti');
    final accra = GhanaPlaces.resolve(city: 'Accra', region: 'Greater Accra');
    expect(GhanaPlaces.distanceKm(accra, kumasi), greaterThan(150));

    await LocalCommerceStore.upsertSeller(
      const Seller(
        id: 'seller-1',
        slug: 'seller-1',
        name: 'Kumasi Crafts',
        city: 'Kumasi',
        region: 'Ashanti',
        address: 'Kejetia Market',
        bio: 'Crafts',
        avatar: '',
        cover: '',
      ),
    );

    final driverUser = HubsomUser(
      id: 'u1',
      email: 'rider@hubsom.test',
      name: 'Ama Rider',
      role: 'huber',
      huberId: 'huber-u1',
      phone: '0240000000',
      city: 'Accra',
      region: 'Greater Accra',
    );
    final profile = await LocalHuberStore.ensureProfileForUser(
      driverUser,
      details: const HuberSignUpDetails(
        phone: '0240000000',
        city: 'Accra',
        region: 'Greater Accra',
      ),
    );

    final order = Order(
      id: 'ord_km_1',
      subtotalGhs: 40,
      status: 'paid',
      lines: const [
        OrderLine(
          productId: 'p1',
          sellerId: 'seller-1',
          name: 'Bead',
          quantity: 1,
          unitPriceGhs: 40,
          lineTotalGhs: 40,
          category: 'fashion',
        ),
      ],
      shipping: const OrderShipping(
        recipientName: 'Kojo',
        phone: '0241',
        line1: 'Spintex',
        city: 'Accra',
        region: 'Greater Accra',
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
    final offer = dispatched.offers.first;

    expect(offer.huberId, profile.id);
    expect(offer.sellerName, 'Kumasi Crafts');
    expect(offer.pickupCity, 'Kumasi');
    expect(offer.pickupLabel, 'Kejetia Market');
    expect(offer.pickupDistanceKm, greaterThan(150));
    expect(offer.pickupDistanceLabel, contains('km to pickup'));
    expect(offer.pickupLatitude, closeTo(kumasi.latitude, 0.05));
    expect(offer.pickupLongitude, closeTo(kumasi.longitude, 0.05));
  });
}
