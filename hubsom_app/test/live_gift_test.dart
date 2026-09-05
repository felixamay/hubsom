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

  test('host cannot gift their own live', () async {
    final stream = await goLive();
    final host = HubsomUser.fromJson(
      Map<String, dynamic>.from(jsonDecode(LocalStore.userJson!) as Map),
    );
    await LocalStore.setUserJson(
      jsonEncode(host.copyWith(giftPoints: 500).toJson()),
    );

    await expectLater(
      repo.sendGift(streamId: stream.id, giftId: 'rose'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Hosts cannot gift'),
        ),
      ),
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
