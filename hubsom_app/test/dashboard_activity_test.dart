import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/providers/core_providers.dart';
import 'package:hubsom_app/core/repositories/auth_repository.dart';
import 'package:hubsom_app/core/repositories/live_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_huber_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/features/dashboard/dashboard_page.dart';
import 'package:hubsom_app/models/order.dart';
import 'package:hubsom_app/models/stream.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

ApiClient _unusedApi() => ApiClient(
      dio: Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:1',
          connectTimeout: const Duration(milliseconds: 1),
          receiveTimeout: const Duration(milliseconds: 1),
        ),
      ),
    );

class _LocalAuthRepository extends AuthRepository {
  _LocalAuthRepository() : super(_unusedApi());

  @override
  Future<HubsomUser?> fetchProfile() async => currentUser();
}

class _LocalLiveRepository extends LiveRepository {
  _LocalLiveRepository() : super(_unusedApi());

  @override
  Future<List<LiveStream>> listStreams({String? status}) async {
    return LocalCommerceStore.listStreams(status: status);
  }
}

const _buyer = HubsomUser(
  id: 'buyer-1',
  email: 'buyer@hubsom.test',
  name: 'Ama Buyer',
  role: 'buyer',
);

const _order = Order(
  id: 'ord-dash-1',
  subtotalGhs: 80,
  status: 'shipped',
  userId: 'buyer-1',
  buyerName: 'Ama Buyer',
  buyerEmail: 'buyer@hubsom.test',
  lines: [
    OrderLine(
      productId: 'p1',
      sellerId: 'seller-1',
      name: 'Kente tote',
      quantity: 1,
      unitPriceGhs: 80,
      lineTotalGhs: 80,
      category: 'fashion',
    ),
  ],
  createdAt: '2026-09-05T12:00:00.000Z',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-dashboard');
    Hive.init(dir.path);
    await LocalStore.init();
  });

  setUp(() {
    CloudStore.useNetwork = false;
  });

  testWidgets('signed-in dashboard shows activity tabs with progress', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await LocalHuberStore.saveOrder(_order);
      await LocalHuberStore.createShipmentFromOrders(
        orderIds: const ['ord-dash-1'],
        sellerId: 'seller-1',
        createdByUserId: 'seller-1',
      );
      await LocalStore.setSessionToken('sess');
      await LocalStore.setUserJson(jsonEncode(_buyer.toJson()));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_LocalAuthRepository()),
          liveRepositoryProvider.overrideWithValue(_LocalLiveRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardPage())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Welcome back, Ama Buyer.'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Purchases (1)'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Bids (0)'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Offers (1)'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Saved (0)'), findsOneWidget);
    expect(find.text('Kente tote'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Processing'), findsOneWidget);
    expect(find.text('Shipped'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Bids (0)'));
    await tester.pumpAndSettle();
    expect(find.text('No bids yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Offers (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Shipment'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Saved (0)'));
    await tester.pumpAndSettle();
    expect(find.text('No saved products'), findsOneWidget);
  });
}
