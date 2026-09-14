import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/live_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/gift_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/features/wallet/received_gifts_page.dart';
import 'package:hubsom_app/features/wallet/wallet_page.dart';
import 'package:hubsom_app/models/live_gift.dart';
import 'package:hubsom_app/models/stream.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:hubsom_app/widgets/live_gift_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HubsomUser seller;
  late HubsomUser viewer;
  late LiveRepository repo;

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-live-qty');
    Hive.init(dir.path);
    await LocalStore.init();

    seller = const HubsomUser(
      id: 'seller-1',
      email: 'seller@hubsom.test',
      name: 'Ama Host',
      role: 'seller',
    );
    viewer = const HubsomUser(
      id: 'viewer-1',
      email: 'viewer@hubsom.test',
      name: 'Efua Fan',
      role: 'buyer',
      walletBalanceGhs: 20,
    );
    repo = LiveRepository(ApiClient());
    await _putVault(seller);
    await LocalStore.setUserJson(jsonEncode(seller.toJson()));
  });

  Future<({LiveStream stream, String productId})> goLive({
    int stock = 8,
    Map<String, int>? quantities,
  }) async {
    final product = await LocalCommerceStore.createProduct(
      user: seller,
      name: 'Shea butter',
      description: 'Raw',
      category: 'beauty',
      priceGhs: 40,
      stock: stock,
      images: const ['img1', 'img2', 'img3'],
    );
    final stream = await LocalCommerceStore.createStream(
      user: seller,
      title: 'Night live',
      cover: 'https://cdn.hubsom.test/live-thumb.jpg',
      productIds: [product.id],
      productQuantities: quantities == null
          ? null
          : {product.id: quantities.values.first},
      pinnedProductId: product.id,
    );
    return (stream: stream, productId: product.id);
  }

  test('go-live stores the selected product quantity', () async {
    final live = await goLive(stock: 8, quantities: {'x': 3});
    expect(live.stream.productQuantities[live.productId], 3);
    expect(live.stream.offeredQty(live.productId, fallback: 8), 3);
    final stored = LocalCommerceStore.getStream(live.stream.id);
    expect(stored?.productQuantities[live.productId], 3);
  });

  test('quantity above stock is rejected before going live', () async {
    final product = await LocalCommerceStore.createProduct(
      user: seller,
      name: 'Kente',
      description: 'Cloth',
      category: 'fashion',
      priceGhs: 90,
      stock: 2,
      images: const ['img1', 'img2', 'img3'],
    );
    await expectLater(
      LocalCommerceStore.createStream(
        user: seller,
        title: 'Too many',
        cover: 'https://cdn.hubsom.test/live-thumb.jpg',
        productIds: [product.id],
        productQuantities: {product.id: 5},
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('only has 2 in stock'),
        ),
      ),
    );
  });

  test('buying from live decrements remaining quantity', () async {
    final live = await goLive(stock: 5, quantities: {'x': 2});
    final next = await LocalCommerceStore.decrementLiveQuantity(
      streamId: live.stream.id,
      productId: live.productId,
    );
    expect(next.offeredQty(live.productId), 1);
    await LocalCommerceStore.decrementLiveQuantity(
      streamId: live.stream.id,
      productId: live.productId,
    );
    await expectLater(
      LocalCommerceStore.decrementLiveQuantity(
        streamId: live.stream.id,
        productId: live.productId,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Sold out'),
        ),
      ),
    );
  });

  test('received gifts list and withdraw move earnings to wallet', () async {
    final live = await goLive();
    final host = HubsomUser.fromJson(
      Map<String, dynamic>.from(jsonDecode(LocalStore.userJson!) as Map),
    );
    await _putVault(host);

    await LocalStore.setUserJson(jsonEncode(viewer.toJson()));
    await _putVault(viewer);
    await repo.buyGiftPoints(packId: 'p100', paymentMethod: 'paystack');
    await repo.sendGift(streamId: live.stream.id, giftId: 'heart');

    final received = GiftStore.receivedFor(live.stream.sellerId);
    expect(received, hasLength(1));
    expect(received.first.giftName, 'Heart');
    expect(received.first.senderName, 'Efua Fan');
    expect(received.first.hostShareGhs, GiftCatalog.hostShareGhs(10));

    await LocalStore.setUserJson(jsonEncode(host.toJson()));
    final hostFresh = HubsomUser.fromJson(
      Map<String, dynamic>.from(
        LocalStore.loadCredentialVault()[host.email.toLowerCase()]!['userJson']
            as Map,
      ),
    );
    expect(hostFresh.giftEarningsGhs, GiftCatalog.hostShareGhs(10));

    final withdrawn = await GiftStore.withdrawEarnings(hostFresh);
    expect(withdrawn.giftEarningsGhs, 0);
    expect(
      withdrawn.walletBalanceGhs,
      hostFresh.walletBalanceGhs + GiftCatalog.hostShareGhs(10),
    );
    expect(GiftStore.hostEarnings(live.stream.sellerId), 0);
    expect(GiftStore.pendingEarningsGhs(withdrawn), 0);
    expect(
      GiftStore.listLedger(userId: withdrawn.id).first.kind,
      'withdraw',
    );
  });

  testWidgets('host gift tiles are tappable', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LiveGiftSheet(
              streamId: 'live-missing',
              hostMode: true,
              onSent: _noopGift,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Rose'), findsOneWidget);
    expect(find.text('Buy gift points'), findsOneWidget);
    final rose = tester.widget<InkWell>(
      find.ancestor(of: find.text('Rose'), matching: find.byType(InkWell)).first,
    );
    expect(rose.onTap, isNotNull);
  });

  testWidgets('wallet opens received gifts and withdraw', (tester) async {
    final router = GoRouter(
      initialLocation: '/wallet',
      routes: [
        GoRoute(path: '/wallet', builder: (_, __) => const WalletPage()),
        GoRoute(
          path: '/wallet/gifts',
          builder: (_, __) => const ReceivedGiftsPage(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Received gifts & withdraw'), findsOneWidget);
    await tester.tap(find.text('Received gifts & withdraw'));
    await tester.pumpAndSettle();
    expect(find.text('Received gifts'), findsWidgets);
    expect(find.text('Withdraw to wallet'), findsOneWidget);
  });
}

void _noopGift(LiveGift gift) {}

Future<void> _putVault(HubsomUser user) async {
  final vault = LocalStore.loadCredentialVault();
  vault[user.email.toLowerCase()] = {
    'salt': 's',
    'hash': 'h',
    'userJson': user.toJson(),
    'email': user.email.toLowerCase(),
  };
  await LocalStore.saveCredentialVault(vault);
}
