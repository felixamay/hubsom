import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/seller_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/ghana_places.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_huber_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/core/services/maps_service.dart';
import 'package:hubsom_app/models/huber.dart';
import 'package:hubsom_app/models/order.dart';
import 'package:hubsom_app/models/seller.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-osm-nav');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  test('navigation target is seller store until pickup, then buyer', () {
    const store = LatLng(5.55, -0.18);
    const buyer = LatLng(5.66, -0.02);
    expect(
      MapsService.navigationTarget(
        status: 'en_route_pickup',
        pickup: store,
        dropoff: buyer,
      ),
      store,
    );
    expect(MapsService.navigatingToPickup('accepted'), isTrue);
    expect(
      MapsService.navigationTarget(
        status: 'en_route_dropoff',
        pickup: store,
        dropoff: buyer,
      ),
      buyer,
    );
    expect(MapsService.navigatingToPickup('picked_up'), isFalse);
    final uri = MapsService.osmDirectionsUri(store, buyer);
    expect(uri.host, 'www.openstreetmap.org');
    expect(uri.queryParameters['route'], contains('5.55'));
  });

  test('seller GPS pin is used for Huber pickup, not city center', () async {
    await LocalCommerceStore.upsertSeller(
      const Seller(
        id: 'seller-gps',
        slug: 'seller-gps',
        name: 'East Legon Shop',
        city: 'Accra',
        region: 'Greater Accra',
        address: 'American House',
        bio: '',
        avatar: '',
        cover: '',
        latitude: 5.636,
        longitude: -0.151,
      ),
    );

    final driverUser = HubsomUser(
      id: 'rider-gps',
      email: 'rider-gps@hubsom.test',
      name: 'Ama Rider',
      role: 'huber',
      huberId: 'huber-gps',
      phone: '0240000001',
      city: 'Accra',
      region: 'Greater Accra',
    );
    await LocalHuberStore.ensureProfileForUser(
      driverUser,
      details: const HuberSignUpDetails(
        phone: '0240000001',
        city: 'Accra',
        region: 'Greater Accra',
      ),
    );
    await LocalHuberStore.upsertProfile(
      LocalHuberStore.profileById('huber-gps')!.copyWith(
        latitude: 5.555,
        longitude: -0.182,
      ),
    );

    final order = Order(
      id: 'ord_gps_1',
      subtotalGhs: 40,
      status: 'paid',
      lines: const [
        OrderLine(
          productId: 'p1',
          sellerId: 'seller-gps',
          name: 'Bag',
          quantity: 1,
          unitPriceGhs: 40,
          lineTotalGhs: 40,
          category: 'fashion',
        ),
      ],
      shipping: const OrderShipping(
        recipientName: 'Kojo',
        phone: '0241',
        line1: 'Tema Community 1',
        city: 'Tema',
        region: 'Greater Accra',
        location: GeoLocation(
          latitude: 5.6667,
          longitude: -0.0167,
          source: 'gps',
        ),
      ),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    await LocalHuberStore.saveOrder(order);
    final shipment = await LocalHuberStore.createShipmentFromOrders(
      orderIds: [order.id],
      sellerId: 'seller-gps',
      createdByUserId: 'seller-gps',
    );
    expect(shipment.destination.location?.latitude, closeTo(5.6667, 0.0001));
    expect(shipment.destination.location?.source, 'gps');

    final dispatched = await LocalHuberStore.dispatchToHubers(shipment);
    final offer = dispatched.offers.first;
    expect(offer.pickupLatitude, closeTo(5.636, 0.0001));
    expect(offer.pickupLongitude, closeTo(-0.151, 0.0001));
    expect(offer.dropoffLatitude, closeTo(5.6667, 0.0001));
    expect(offer.pickupDistanceKm, greaterThan(0));
    expect(
      offer.pickupDistanceKm,
      closeTo(
        GhanaPlaces.distanceKm(
          const LatLng(5.555, -0.182),
          const LatLng(5.636, -0.151),
        ),
        0.2,
      ),
    );
  });

  test('updateStore keeps explicit seller GPS coordinates', () async {
    await LocalStore.setUserJson(
      jsonEncode({
        'id': 'u-gps',
        'email': 'gps-seller@hubsom.test',
        'name': 'GPS Seller',
        'role': 'seller',
      }),
    );
    final repo = SellerRepository(ApiClient());
    final updated = await repo.updateStore({
      'name': 'GPS Store',
      'address': 'Labone',
      'city': 'Accra',
      'region': 'Greater Accra',
      'bio': '',
      'latitude': 5.5642,
      'longitude': -0.1711,
    });
    expect(updated.latitude, closeTo(5.5642, 0.0001));
    expect(updated.longitude, closeTo(-0.1711, 0.0001));
  });
}
