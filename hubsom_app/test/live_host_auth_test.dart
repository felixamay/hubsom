import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/auth_repository.dart';
import 'package:hubsom_app/core/repositories/live_repository.dart';
import 'package:hubsom_app/core/services/api_client.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/local_commerce_store.dart';
import 'package:hubsom_app/core/services/local_store.dart';
import 'package:hubsom_app/models/stream.dart';
import 'package:hubsom_app/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HubsomUser seller;
  late HubsomUser stranger;

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-live-host-auth');
    Hive.init(dir.path);
    await LocalStore.init();

    seller = const HubsomUser(
      id: 'seller-1',
      email: 'seller@hubsom.test',
      name: 'Ama Host',
      role: 'seller',
    );
    stranger = const HubsomUser(
      id: 'intruder-1',
      email: 'intruder@hubsom.test',
      name: 'Kojo Intruder',
      role: 'buyer',
    );
    await LocalStore.setUserJson(jsonEncode(seller.toJson()));
    await LocalStore.setSessionToken('host-sess');
  });

  Future<LiveStream> goLive() async {
    final product = await LocalCommerceStore.createProduct(
      user: seller,
      name: 'Kente scarf',
      description: 'Handwoven',
      category: 'fashion',
      priceGhs: 200,
      stock: 3,
      images: const ['img1', 'img2', 'img3'],
    );

    return LocalCommerceStore.createStream(
      user: seller,
      title: 'Sunday live bargains',
      productIds: [product.id],
      pinnedProductId: product.id,
      auctionProductId: product.id,
      startingBidGhs: 80,
      askingPriceGhs: 150,
      auctionDurationSeconds: 30,
    );
  }

  test('isHostOf ignores a missing session and a stranger', () async {
    final stream = await goLive();
    expect(LocalCommerceStore.isHostOf(stream, null), isFalse);
    expect(LocalCommerceStore.isHostOf(stream, stranger), isFalse);
    expect(LocalCommerceStore.isHostOf(stream, seller), isTrue);
  });

  test('stranger cannot end, pin, or extend someone else\'s live show', () async {
    final stream = await goLive();
    final originalPin = stream.pinnedProductId;
    final originalEndsAt = stream.auction!.endsAt;

    await LocalStore.setUserJson(jsonEncode(stranger.toJson()));
    await LocalStore.setSessionToken('intruder-sess');

    final live = LiveRepository(ApiClient());
    expect(
      () => live.endStream(stream.id),
      throwsA(isA<AuthException>()),
    );
    expect(
      () => live.pinProduct(stream.id, 'not-yours'),
      throwsA(isA<AuthException>()),
    );
    expect(
      () => live.extendAuction(stream.id, seconds: 30),
      throwsA(isA<AuthException>()),
    );

    final after = LocalCommerceStore.getStream(stream.id)!;
    expect(after.isLive, isTrue);
    expect(after.pinnedProductId, originalPin);
    expect(after.auction?.endsAt, originalEndsAt);
    expect(after.auction?.status, 'open');
  });

  test('signed-out visitor cannot end a live show', () async {
    final stream = await goLive();
    await LocalStore.setUserJson(null);
    await LocalStore.setSessionToken(null);

    expect(
      () => LiveRepository(ApiClient()).endStream(stream.id),
      throwsA(isA<AuthException>()),
    );
    expect(LocalCommerceStore.getStream(stream.id)!.isLive, isTrue);
  });

  test('host can still end their own live show', () async {
    final stream = await goLive();
    final live = LiveRepository(ApiClient());
    final ended = await live.endStream(stream.id);
    expect(ended.isLive, isFalse);
    expect(ended.status, 'ended');
  });
}
