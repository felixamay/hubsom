import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/repositories/order_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_huber_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/features/seller/seller_orders_page.dart';
import 'package:hubsom_app/models/huber.dart';
import 'package:hubsom_app/models/order.dart';
import 'package:hubsom_app/models/shipment.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _init() async {
  AppConfig.load();
  CloudStore.useNetwork = false;
  SharedPreferences.setMockInitialValues({});
  final dir = Directory.systemTemp.createTempSync('hubsom-offer-details');
  Hive.init(dir.path);
  await LocalStore.init();
}

Order _order({
  String phone = '',
  String line1 = '',
  String city = 'Accra',
}) {
  return Order(
    id: 'ord-offer-1',
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
    shipping: OrderShipping(
      recipientName: 'Kojo Buyer',
      phone: phone,
      line1: line1,
      city: city,
      region: 'Greater Accra',
    ),
    createdAt: DateTime.now().toUtc().toIso8601String(),
  );
}

class _LocalOrderRepository extends OrderRepository {
  _LocalOrderRepository()
      : super(
          ApiClient(
            dio: Dio(
              BaseOptions(
                baseUrl: 'http://127.0.0.1:1',
                connectTimeout: const Duration(milliseconds: 1),
                receiveTimeout: const Duration(milliseconds: 1),
              ),
            ),
          ),
        );

  @override
  Future<List<Order>> sellerOrders() async => LocalHuberStore.listOrders();

  @override
  Future<List<Shipment>> listShipments() async =>
      LocalHuberStore.listShipments();

  @override
  Future<Order> updateOrder(String orderId, Map<String, dynamic> patch) {
    final shipping = patch['shipping'] is Map
        ? OrderShipping.fromJson(Map<String, dynamic>.from(patch['shipping'] as Map))
        : null;
    return LocalHuberStore.updateOrderDetails(
      orderId,
      status: patch['status'] as String?,
      shipping: shipping,
    );
  }
}

Future<HuberProfile> _rider() async {
  final driverUser = const HubsomUser(
    id: 'u-rider',
    email: 'rider@hubsom.test',
    name: 'Ama Rider',
    role: 'huber',
    huberId: 'huber-u-rider',
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
  return profile;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_init);

  test('dispatch requires seller fee, customer phone and location', () async {
    await _rider();
    await LocalHuberStore.saveOrder(_order());
    final shipment = await LocalHuberStore.createShipmentFromOrders(
      orderIds: const ['ord-offer-1'],
      sellerId: 'seller-1',
      createdByUserId: 'seller-1',
    );
    await expectLater(
      LocalHuberStore.dispatchToHubers(shipment),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('shipment fee'),
        ),
      ),
    );

    final withFee = await LocalHuberStore.updateShipmentDetails(
      shipment.id,
      offeredFeeGhs: 30,
    );
    await expectLater(
      LocalHuberStore.dispatchToHubers(withFee),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('phone'),
        ),
      ),
    );

    final withPhone = await LocalHuberStore.updateShipmentDetails(
      shipment.id,
      destination: const OrderShipping(
        recipientName: 'Kojo Buyer',
        phone: '0241111111',
        line1: '',
        city: '',
        region: 'Greater Accra',
      ),
      offeredFeeGhs: 30,
    );
    await expectLater(
      LocalHuberStore.dispatchToHubers(withPhone),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('location'),
        ),
      ),
    );
  });

  test('seller fee, location and phone are sent on rider offers', () async {
    final rider = await _rider();
    await LocalHuberStore.saveOrder(
      _order(phone: '0241111111', line1: '12 Spintex Rd'),
    );
    final shipment = await LocalHuberStore.createShipmentFromOrders(
      orderIds: const ['ord-offer-1'],
      sellerId: 'seller-1',
      createdByUserId: 'seller-1',
      offeredFeeGhs: 45,
      destination: const OrderShipping(
        recipientName: 'Kojo Buyer',
        phone: '0249998888',
        line1: 'East Legon junction',
        city: 'Accra',
        region: 'Greater Accra',
      ),
    );
    expect(shipment.offeredFeeGhs, 45);
    expect(shipment.destination.phone, '0249998888');
    expect(shipment.destination.line1, 'East Legon junction');

    final dispatched = await LocalHuberStore.dispatchToHubers(shipment);
    final offer = dispatched.offers.first;
    expect(offer.huberId, rider.id);
    expect(offer.offeredFeeGhs, 45);
    expect(offer.recipientPhone, '0249998888');
    expect(offer.dropoffLine1, 'East Legon junction');
    expect(offer.recipientName, 'Kojo Buyer');

    final delivery = await LocalHuberStore.acceptOffer(
      offerId: offer.id,
      driver: LocalHuberStore.profileById(rider.id)!,
    );
    expect(delivery.feeGhs, 45);
    expect(delivery.customerPhone, '0249998888');
    expect(delivery.dropoffAddress, contains('East Legon junction'));
  });

  testWidgets('seller can add delivery details from an order', (tester) async {
    await tester.runAsync(() async {
      await LocalStore.setUserJson(
        jsonEncode({
          'id': 'seller-1',
          'email': 'seller@hubsom.test',
          'name': 'Ama Host',
          'role': 'seller',
          'sellerId': 'seller-1',
        }),
      );
      await LocalHuberStore.saveOrder(_order());
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(_LocalOrderRepository()),
        ],
        child: const MaterialApp(home: SellerOrdersPage()),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Add delivery details'), findsOneWidget);
    await tester.tap(find.text('Add delivery details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Customer delivery details'), findsOneWidget);
    expect(find.text('Customer phone'), findsOneWidget);
    expect(find.text('Customer location / address'), findsOneWidget);
    expect(find.text('Shipment fee (GHS)'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Customer phone'),
      '0245551212',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Customer location / address'),
      'Labone',
    );
    await tester.tap(find.text('Save for riders'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('0245551212'), findsWidgets);
  });
}
