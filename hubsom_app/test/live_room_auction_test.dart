import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/catalog_repository.dart';
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
  late HubsomUser bidder;

  setUp(() async {
    AppConfig.load();
    CloudStore.useNetwork = false;
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('hubsom-live-room');
    Hive.init(dir.path);
    await LocalStore.init();

    seller = const HubsomUser(
      id: 'seller-1',
      email: 'seller@hubsom.test',
      name: 'Ama Host',
      role: 'seller',
    );
    bidder = const HubsomUser(
      id: 'buyer-1',
      email: 'buyer@hubsom.test',
      name: 'Kojo Bidder',
      role: 'buyer',
    );
    await LocalStore.setUserJson(jsonEncode(seller.toJson()));
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
    );
  }

  test('live auction accepts bids with history and soft-close', () async {
    final stream = await goLive();
    expect(stream.hosts.first.name, 'Ama Host');
    expect(stream.auction, isNotNull);
    expect(stream.auction!.isOpen, isTrue);
    expect(stream.auction!.currentBidGhs, 80);

    final nearEnd = stream.auction!.copyWith(
      endsAt: DateTime.now()
          .toUtc()
          .add(const Duration(seconds: 20))
          .toIso8601String(),
    );
    await LocalCommerceStore.updateStream(stream.id, auction: nearEnd);

    final first = await LocalCommerceStore.placeBid(
      auctionId: nearEnd.id,
      amountGhs: nearEnd.nextMinBidGhs,
      bidder: bidder,
    );
    expect(first.currentBidGhs, greaterThan(80));
    expect(first.highestBidder, 'Kojo Bidder');
    expect(first.recentBids, isNotEmpty);
    expect(first.recentBids.first.bidderName, 'Kojo Bidder');
    final left = first.timeLeft!;
    expect(left.inSeconds, greaterThanOrEqualTo(40));

    final chat = LocalCommerceStore.listChat(stream.id);
    expect(chat.any((m) => m.text.contains('Bid')), isTrue);
  });

  test('follow seller persists locally for live Follow chip', () async {
    final catalog = CatalogRepository(ApiClient());
    expect(catalog.isFollowingSeller('seller-u-seller-1'), isFalse);

    await LocalStore.setUserJson(jsonEncode(bidder.toJson()));
    final following = await catalog.followSeller('seller-u-seller-1');
    expect(following, isTrue);
    expect(catalog.isFollowingSeller('seller-u-seller-1'), isTrue);

    final unfollowed = await catalog.unfollowSeller('seller-u-seller-1');
    expect(unfollowed, isFalse);
    expect(catalog.isFollowingSeller('seller-u-seller-1'), isFalse);
  });

  test('LiveAuction.isOpen reflects status and end time', () {
    final open = LiveAuction(
      id: 'a1',
      productId: 'p1',
      startingBidGhs: 50,
      currentBidGhs: 50,
      minIncrementGhs: 5,
      endsAt: DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
      status: 'open',
    );
    expect(open.isOpen, isTrue);
    expect(open.nextMinBidGhs, 55);

    final ended = open.copyWith(
      endsAt: DateTime.now()
          .toUtc()
          .subtract(const Duration(seconds: 1))
          .toIso8601String(),
    );
    expect(ended.isOpen, isFalse);
  });
}
