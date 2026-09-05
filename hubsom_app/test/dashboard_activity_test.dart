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
import 'package:hubsom_app/core/repositories/order_repository.dart';
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
    expect(find.text('No lots won yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Offers (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Shipment'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Saved (0)'));
    await tester.pumpAndSettle();
    expect(find.text('No saved products'), findsOneWidget);
  });

  testWidgets('short phone dashboard scrolls and activity chips stay tappable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

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
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Hubsom')),
            body: const DashboardPage(),
            bottomNavigationBar: NavigationBar(
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(
                  icon: Icon(Icons.insights),
                  label: 'Dashboard',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byKey(const Key('dashboard-stats')), findsOneWidget);

    await tester.tap(find.text('Offers'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Shipment'), findsWidgets);

    await tester.tap(find.text('Purchases'));
    await tester.pumpAndSettle();
    expect(find.text('Kente tote'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(Tab, 'Purchases (1)'), findsOneWidget);
  });

  test('buyerOrders is what the user bought, not sales to them', () async {
    const seller = HubsomUser(
      id: 'seller-1',
      email: 'seller@hubsom.test',
      name: 'Ama Host',
      role: 'seller',
      sellerId: 'seller-1',
    );
    const saleToCustomer = Order(
      id: 'ord-sale-1',
      subtotalGhs: 40,
      status: 'paid',
      userId: 'customer-9',
      buyerEmail: 'kojo@hubsom.test',
      lines: [
        OrderLine(
          productId: 'p-sale',
          sellerId: 'seller-1',
          name: 'Sold from my store',
          quantity: 1,
          unitPriceGhs: 40,
          lineTotalGhs: 40,
          category: 'fashion',
        ),
      ],
      createdAt: '2026-09-05T13:00:00.000Z',
    );
    const myPurchase = Order(
      id: 'ord-buy-1',
      subtotalGhs: 25,
      status: 'paid',
      userId: 'seller-1',
      buyerEmail: 'seller@hubsom.test',
      lines: [
        OrderLine(
          productId: 'p-other',
          sellerId: 'other-seller',
          name: 'Shea I bought',
          quantity: 1,
          unitPriceGhs: 25,
          lineTotalGhs: 25,
          category: 'beauty',
        ),
      ],
      createdAt: '2026-09-05T13:05:00.000Z',
    );
    await LocalHuberStore.saveOrder(saleToCustomer);
    await LocalHuberStore.saveOrder(myPurchase);
    await LocalStore.setUserJson(jsonEncode(seller.toJson()));

    final repo = OrderRepository(_unusedApi());
    final mine = await repo.buyerOrders();
    expect(mine.map((o) => o.id), ['ord-buy-1']);
    expect(mine.single.lines.single.name, 'Shea I bought');

    await LocalStore.setUserJson(jsonEncode(_buyer.toJson()));
    final buyerRepo = OrderRepository(_unusedApi());
    final bought = await buyerRepo.buyerOrders();
    expect(bought.any((o) => o.id == 'ord-sale-1'), isFalse);
    expect(bought.any((o) => o.id == 'ord-dash-1'), isTrue);
  });

  testWidgets('bids are lots the user won and follow seller fulfillment', (
    tester,
  ) async {
    const win = Order(
      id: 'ord_auc_auc-win',
      subtotalGhs: 90,
      status: 'processing',
      userId: 'buyer-1',
      buyerName: 'Ama Buyer',
      buyerEmail: 'buyer@hubsom.test',
      streamId: 'live-win-1',
      paymentMethods: ['live-auction'],
      lines: [
        OrderLine(
          productId: 'p-lot',
          sellerId: 'seller-1',
          name: 'Auction kente',
          quantity: 1,
          unitPriceGhs: 90,
          lineTotalGhs: 90,
          category: 'fashion',
        ),
      ],
      createdAt: '2026-09-05T14:00:00.000Z',
    );

    await tester.runAsync(() async {
      await LocalHuberStore.saveOrder(_order);
      await LocalHuberStore.saveOrder(win);
      await LocalCommerceStore.upsertStream(
        LiveStream(
          id: 'live-win-1',
          title: 'Sunday live bargains',
          description: 'Live',
          sellerId: 'seller-1',
          status: 'ended',
          channelName: 'live-win-1',
          cover: '',
          auction: LiveAuction(
            id: 'auc-win',
            productId: 'p-lot',
            startingBidGhs: 50,
            currentBidGhs: 90,
            minIncrementGhs: 5,
            endsAt: '2026-09-01T00:00:00.000Z',
            highestBidder: 'Ama Buyer',
            highestBidderId: 'buyer-1',
            highestBidderEmail: 'buyer@hubsom.test',
            status: 'sold',
            orderId: 'ord_auc_auc-win',
            recentBids: const [
              AuctionBid(
                bidderName: 'Ama Buyer',
                amountGhs: 90,
                at: '2026-09-01T00:00:00.000Z',
                bidderId: 'buyer-1',
              ),
            ],
          ),
        ),
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

    expect(find.widgetWithText(Tab, 'Purchases (1)'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Bids (1)'), findsOneWidget);
    expect(find.text('Kente tote'), findsOneWidget);
    expect(find.text('Auction kente'), findsNothing);

    await tester.tap(find.widgetWithText(Tab, 'Bids (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Auction kente'), findsOneWidget);
    expect(find.textContaining('Won'), findsWidgets);
    expect(find.textContaining('Preparing'), findsWidgets);

    await tester.runAsync(() async {
      await LocalHuberStore.updateOrderStatus('ord_auc_auc-win', 'shipped');
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
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();
    await tester.tap(find.widgetWithText(Tab, 'Bids (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('On the way'), findsWidgets);
  });

  testWidgets('seller dashboard does not list customer sales as purchases', (
    tester,
  ) async {
    const seller = HubsomUser(
      id: 'seller-dash-1',
      email: 'host@hubsom.test',
      name: 'Ama Host',
      role: 'seller',
      sellerId: 'seller-1',
    );
    await tester.runAsync(() async {
      await LocalHuberStore.saveOrder(_order);
      await LocalStore.setSessionToken('sess');
      await LocalStore.setUserJson(jsonEncode(seller.toJson()));
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

    expect(find.text('Welcome back, Ama Host.'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Purchases (0)'), findsOneWidget);
    expect(find.text('Kente tote'), findsNothing);
    expect(find.text('No purchases yet'), findsOneWidget);
  });
}
