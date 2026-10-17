import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/live_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/gift_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/live_gift.dart';
import 'package:hubsom_app/models/stream.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HubsomUser seller;
  late HubsomUser viewer;
  late LiveRepository repo;

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    GiftStore.debugIncomingGiftPoints = null;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-live-gift');
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
      walletBalanceGhs: 100,
    );
    repo = LiveRepository(ApiClient());
    await LocalStore.setString('localGiftLedger', '[]');
    await LocalStore.setString('localGiftHostEarnings', '{}');
    await _putVault(seller);
    await LocalStore.setUserJson(jsonEncode(seller.toJson()));
  });

  Future<LiveStream> goLive() async {
    final product = await LocalCommerceStore.createProduct(
      user: seller,
      name: 'Shea butter',
      description: 'Raw',
      category: 'beauty',
      priceGhs: 40,
      stock: 8,
      images: const ['img1', 'img2', 'img3'],
    );
    return LocalCommerceStore.createStream(
      user: seller,
      title: 'Night live',
      cover: 'https://cdn.hubsom.test/live-thumb.jpg',
      productIds: [product.id],
      pinnedProductId: product.id,
    );
  }

  test('gift catalog prices and host share', () {
    expect(GiftCatalog.gifts.length, 8);
    expect(GiftCatalog.byId('rose')!.costPoints, 1);
    expect(GiftCatalog.byId('diamond')!.costPoints, 999);
    expect(GiftCatalog.packById('p100')!.priceGhs, 10);
    expect(GiftCatalog.hostShareGhs(10), 0.8);
    expect(GiftCatalog.hostShareGhs(100), 8);
  });

  test('user json keeps gift points and earnings', () {
    final user = viewer.copyWith(giftPoints: 40, giftEarningsGhs: 2.4);
    final round = HubsomUser.fromJson(user.toJson());
    expect(round.giftPoints, 40);
    expect(round.giftEarningsGhs, 2.4);
  });

  test('buying a pack with MoMo credits points without wallet debit', () async {
    await LocalStore.setUserJson(jsonEncode(viewer.toJson()));
    await _putVault(viewer);

    final next = await repo.buyGiftPoints(
      packId: 'p100',
      paymentMethod: 'mtn-momo',
    );
    expect(next.giftPoints, 100);
    expect(next.walletBalanceGhs, 100);
    expect(
      GiftStore.listLedger(userId: viewer.id).first.kind,
      'purchase',
    );
  });

  test('wallet pack purchase deducts GHS and rejects a short balance', () async {
    await LocalStore.setUserJson(jsonEncode(viewer.toJson()));
    await _putVault(viewer);

    final next = await repo.buyGiftPoints(
      packId: 'p100',
      paymentMethod: 'wallet',
    );
    expect(next.giftPoints, 100);
    expect(next.walletBalanceGhs, 90);

    await expectLater(
      repo.buyGiftPoints(packId: 'p3000', paymentMethod: 'wallet'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Wallet needs'),
        ),
      ),
    );
  });

  test('viewer sends a live gift, chat records it, host is paid', () async {
    final stream = await goLive();
    final host = HubsomUser.fromJson(
      Map<String, dynamic>.from(jsonDecode(LocalStore.userJson!) as Map),
    );
    await _putVault(host);

    await LocalStore.setUserJson(jsonEncode(viewer.toJson()));
    await _putVault(viewer);
    await repo.buyGiftPoints(packId: 'p100', paymentMethod: 'paystack');

    final sent = await repo.sendGift(streamId: stream.id, giftId: 'heart');
    expect(sent.gift.id, 'heart');
    expect(sent.gift.emoji, '❤️');
    expect(sent.user.giftPoints, 90);

    final chat = LocalCommerceStore.listChat(stream.id);
    expect(
      chat.any(
        (m) =>
            m.text.contains('❤️') &&
            m.text.contains('Heart') &&
            m.text.contains('10 pts'),
      ),
      isTrue,
    );

    expect(GiftStore.hostEarnings(stream.sellerId), GiftCatalog.hostShareGhs(10));
    final vault = LocalStore.loadCredentialVault();
    final hostJson = Map<String, dynamic>.from(
      vault[host.email.toLowerCase()]!['userJson'] as Map,
    );
    expect(
      HubsomUser.fromJson(hostJson).giftEarningsGhs,
      GiftCatalog.hostShareGhs(10),
    );

    final stats = await repo.analytics(stream.id);
    expect(stats['giftCount'], 1);
  });

  test('insufficient points and unknown gifts fail', () async {
    final stream = await goLive();
    await LocalStore.setUserJson(jsonEncode(viewer.toJson()));
    await _putVault(viewer);

    await expectLater(
      repo.sendGift(streamId: stream.id, giftId: 'rose'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Buy points'),
        ),
      ),
    );
    await expectLater(
      repo.sendGift(streamId: stream.id, giftId: 'unicorn'),
      throwsA(isA<StateError>()),
    );
  });

  test('host can gift their own live without self-earnings', () async {
    final stream = await goLive();
    final host = HubsomUser.fromJson(
      Map<String, dynamic>.from(jsonDecode(LocalStore.userJson!) as Map),
    );
    await LocalStore.setUserJson(
      jsonEncode(host.copyWith(giftPoints: 500).toJson()),
    );
    await _putVault(host.copyWith(giftPoints: 500));

    final before = GiftStore.hostEarnings(stream.sellerId);
    final sent = await repo.sendGift(streamId: stream.id, giftId: 'rose');
    expect(sent.gift.id, 'rose');
    expect(sent.user.giftPoints, 499);
    expect(GiftStore.hostEarnings(stream.sellerId), before);
    expect(
      GiftStore.receivedFor(stream.sellerId)
          .where((e) => e.streamId == stream.id),
      isEmpty,
    );
  });

  test('stale host-earnings map cannot cash out gifts already withdrawn', () async {
    const sellerId = 'sel-stale';
    const share = 8.0;
    await LocalStore.setString(
      'localGiftHostEarnings',
      jsonEncode({sellerId: share}),
    );
    await LocalStore.setString(
      'localGiftLedger',
      jsonEncode([
        {
          'id': 'gft_heart',
          'userId': 'viewer-1',
          'kind': 'send',
          'points': 10,
          'hostSellerId': sellerId,
          'hostShareGhs': share,
          'createdAt': '2026-10-01T10:00:00Z',
        },
        {
          'id': 'gwd_phone',
          'userId': seller.id,
          'kind': 'withdraw',
          'points': 0,
          'priceGhs': share,
          'createdAt': '2026-10-01T11:00:00Z',
        },
      ]),
    );
    final laptopHost = HubsomUser(
      id: seller.id,
      email: seller.email,
      name: seller.name,
      role: 'seller',
      sellerId: sellerId,
    );

    expect(GiftStore.hostEarnings(sellerId), share);
    expect(GiftStore.pendingEarningsGhs(laptopHost), 0);
    await expectLater(
      GiftStore.withdrawEarnings(laptopHost),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('No gift earnings'),
        ),
      ),
    );

    await GiftStore.applyCloudHostEarnings(sellerId: sellerId, balanceGhs: 0);
    expect(GiftStore.hostEarnings(sellerId), 0);
    expect(GiftStore.pendingEarningsGhs(laptopHost), 0);
  });

  test('host on another device is paid from the synced gift ledger', () async {
    final stream = await goLive();
    // Viewer phone: host credentials are not in this vault.
    await LocalStore.setString('localGiftLedger', '[]');
    await LocalStore.setString('localGiftHostEarnings', '{}');
    await LocalStore.saveCredentialVault({});
    await LocalStore.setUserJson(jsonEncode(viewer.toJson()));
    await _putVault(viewer);
    await repo.buyGiftPoints(packId: 'p100', paymentMethod: 'paystack');
    await repo.sendGift(streamId: stream.id, giftId: 'heart');

    // Seller phone after giftLedger hydrate: send rows exist, local
    // host-earnings map and giftEarningsGhs do not.
    await LocalStore.setString('localGiftHostEarnings', '{}');
    final hostOnly = HubsomUser(
      id: seller.id,
      email: seller.email,
      name: seller.name,
      role: 'seller',
      sellerId: stream.sellerId,
    );

    expect(GiftStore.hostEarnings(stream.sellerId), 0);
    expect(hostOnly.giftEarningsGhs, 0);
    expect(
      GiftStore.pendingEarningsGhs(hostOnly),
      GiftCatalog.hostShareGhs(10),
    );
    expect(GiftStore.receivedFor(stream.sellerId), hasLength(1));

    final withdrawn = await GiftStore.withdrawEarnings(hostOnly);
    expect(withdrawn.giftEarningsGhs, 0);
    expect(withdrawn.walletBalanceGhs, GiftCatalog.hostShareGhs(10));
    expect(GiftStore.pendingEarningsGhs(withdrawn), 0);
  });

  test('mergeDocsById keeps local gift sends a partial cloud list omitted', () async {
    await LocalStore.setString(
      'localGiftLedger',
      jsonEncode([
        {
          'id': 'gft_local',
          'userId': 'viewer-1',
          'kind': 'send',
          'points': 10,
          'hostSellerId': 'sel-1',
          'hostShareGhs': 0.8,
          'createdAt': '2026-09-22T00:00:00Z',
        },
      ]),
    );
    final merged = CloudStore.mergeDocsById(
      localKey: 'localGiftLedger',
      incoming: [
        {
          'id': 'gft_cloud',
          'userId': 'viewer-2',
          'kind': 'send',
          'points': 25,
          'hostSellerId': 'sel-1',
          'hostShareGhs': 2.0,
          'createdAt': '2026-09-22T01:00:00Z',
        },
      ],
    );
    expect(merged.map((e) => e['id']), containsAll(['gft_local', 'gft_cloud']));
  });

  test('a second device cannot spend gift points the first already sent',
      () async {
    final stream = await goLive();
    await LocalStore.setUserJson(jsonEncode(viewer.toJson()));
    await _putVault(viewer);
    await repo.buyGiftPoints(packId: 'p100', paymentMethod: 'paystack');
    await repo.sendGift(streamId: stream.id, giftId: 'heart');
    expect(
      GiftStore.listLedger(userId: viewer.id)
          .where((e) => e.kind == 'send' && e.streamId == stream.id),
      hasLength(1),
    );
    expect(GiftStore.hostEarnings(stream.sellerId), GiftCatalog.hostShareGhs(10));

    // Laptop still shows the pre-send 100 pts. Phone already wrote the
    // send row and reduced the cloud balance to 90.
    await LocalStore.setUserJson(
      jsonEncode(viewer.copyWith(giftPoints: 100).toJson()),
    );
    await _putVault(viewer.copyWith(giftPoints: 100));
    GiftStore.debugIncomingGiftPoints = 90;

    // Ledger + cloud both say only 90 remain. A Crown (100) would invent
    // 10 unpaid points and credit the host again.
    await expectLater(
      repo.sendGift(streamId: stream.id, giftId: 'crown'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Buy points'),
        ),
      ),
    );
    expect(
      GiftStore.listLedger(userId: viewer.id).where((e) => e.kind == 'send'),
      hasLength(1),
    );
    expect(GiftStore.hostEarnings(stream.sellerId), GiftCatalog.hostShareGhs(10));

    // Even after the session cache is restored to the purchased 100, the
    // ledger send rows cap what this laptop can still give.
    GiftStore.debugIncomingGiftPoints = null;
    await LocalStore.setUserJson(
      jsonEncode(viewer.copyWith(giftPoints: 100).toJson()),
    );
    expect(
      GiftStore.remainingGiftPoints(viewer.copyWith(giftPoints: 100)),
      90,
    );
    final leftover = await repo.sendGift(streamId: stream.id, giftId: 'heart');
    expect(leftover.user.giftPoints, 80);
    expect(
      GiftStore.listLedger(userId: viewer.id).where((e) => e.kind == 'send'),
      hasLength(2),
    );
  });

  test('stale session points cannot spend a purchase the ledger already sent',
      () async {
    final drained = viewer.copyWith(giftPoints: 100);
    await LocalStore.setString(
      'localGiftLedger',
      jsonEncode([
        {
          'id': 'gpt_pack',
          'userId': viewer.id,
          'kind': 'purchase',
          'points': 100,
          'priceGhs': 10,
          'createdAt': '2026-10-17T10:00:00Z',
        },
        {
          'id': 'gft_phone',
          'userId': viewer.id,
          'kind': 'send',
          'points': 100,
          'hostSellerId': 'sel-1',
          'hostShareGhs': 8,
          'createdAt': '2026-10-17T10:05:00Z',
        },
      ]),
    );

    expect(GiftStore.remainingGiftPoints(drained), 0);
    expect(
      GiftStore.resolveAgainstCloud(
        local: drained,
        remoteGiftPoints: 0,
      ).giftPoints,
      0,
    );
  });

  test('gifts are blocked after the show ends', () async {
    final stream = await goLive();
    await LocalCommerceStore.updateStream(stream.id, end: true);
    await LocalStore.setUserJson(
      jsonEncode(viewer.copyWith(giftPoints: 20).toJson()),
    );

    await expectLater(
      repo.sendGift(streamId: stream.id, giftId: 'rose'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('while the show is live'),
        ),
      ),
    );
  });
}

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
