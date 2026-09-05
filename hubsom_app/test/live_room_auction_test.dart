import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/repositories/catalog_repository.dart';
import 'package:hubsom_app/core/repositories/live_repository.dart';
import 'package:hubsom_app/core/repositories/seller_repository.dart';
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
      askingPriceGhs: 150,
      auctionDurationSeconds: 30,
    );
  }

  test('auction duration is capped at 30 seconds', () async {
    final stream = await goLive();
    final left = stream.auction!.timeLeft!;
    expect(left.inSeconds, lessThanOrEqualTo(30));
    expect(left.inSeconds, greaterThan(25));
  });

  test('live auction accepts bids with history and soft-close', () async {
    final stream = await goLive();
    expect(stream.hosts.first.name, 'Ama Host');
    expect(stream.auction, isNotNull);
    expect(stream.auction!.isOpen, isTrue);
    expect(stream.auction!.currentBidGhs, 80);

    final nearEnd = stream.auction!.copyWith(
      endsAt: DateTime.now()
          .toUtc()
          .add(const Duration(seconds: 2))
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
    expect(first.highestBidderId, 'buyer-1');
    expect(first.recentBids, isNotEmpty);
    expect(first.recentBids.first.bidderName, 'Kojo Bidder');
    expect(first.recentBids.first.amountGhs, first.currentBidGhs);
    expect(first.bidderCount, 1);
    final left = first.timeLeft!;
    expect(left.inSeconds, greaterThanOrEqualTo(4));

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

  test('winning bid creates a seller order when auction ends', () async {
    final stream = await goLive();
    final auction = stream.auction!;
    expect(auction.askingPriceGhs, 150);

    // Meet the asking price.
    await LocalCommerceStore.placeBid(
      auctionId: auction.id,
      amountGhs: 150,
      bidder: bidder,
    );

    // Force clock to zero.
    final ended = LocalCommerceStore.getStream(stream.id)!.auction!.copyWith(
          endsAt: DateTime.now()
              .toUtc()
              .subtract(const Duration(seconds: 1))
              .toIso8601String(),
        );
    await LocalCommerceStore.updateStream(stream.id, auction: ended);

    final order = await LocalCommerceStore.finalizeAuction(stream.id);
    expect(order, isNotNull);
    expect(order!.buyerName, 'Kojo Bidder');
    expect(order.userId, 'buyer-1');
    expect(order.streamId, stream.id);
    expect(order.lines.first.sellerId, stream.sellerId);
    expect(order.status, 'paid');

    final sold = LocalCommerceStore.getStream(stream.id)!.auction!;
    expect(sold.status, 'sold');
    expect(sold.orderId, order.id);

    // Idempotent.
    final again = await LocalCommerceStore.finalizeAuction(stream.id);
    expect(again?.id, order.id);
  });

  test('unmet asking price does not sell — seller can extend', () async {
    final stream = await goLive();
    final auction = stream.auction!;

    await LocalCommerceStore.placeBid(
      auctionId: auction.id,
      amountGhs: auction.nextMinBidGhs, // below ask 150
      bidder: bidder,
    );

    final ended = LocalCommerceStore.getStream(stream.id)!.auction!.copyWith(
          endsAt: DateTime.now()
              .toUtc()
              .subtract(const Duration(seconds: 1))
              .toIso8601String(),
        );
    await LocalCommerceStore.updateStream(stream.id, auction: ended);

    final order = await LocalCommerceStore.finalizeAuction(stream.id);
    expect(order, isNull);
    final reserved = LocalCommerceStore.getStream(stream.id)!.auction!;
    expect(reserved.status, 'reserve_not_met');
    expect(reserved.awaitingExtend, isTrue);

    final extended = await LocalCommerceStore.extendAuction(
      streamId: stream.id,
      seconds: 20,
    );
    expect(extended.isOpen, isTrue);
    expect(extended.status, 'open');
    expect(extended.timeLeft!.inSeconds, greaterThan(15));
  });

  test('host can add more products mid-live', () async {
    final stream = await goLive();
    final extra = await LocalCommerceStore.createProduct(
      user: seller,
      name: 'Beaded bag',
      description: 'Extra lot',
      category: 'fashion',
      priceGhs: 90,
      stock: 2,
      images: const ['a', 'b', 'c'],
    );
    final updated = await LocalCommerceStore.addProductsToStream(
      streamId: stream.id,
      user: seller,
      productIds: [extra.id],
    );
    expect(updated!.productIds, contains(stream.productIds.first));
    expect(updated.productIds, contains(extra.id));
  });

  test('host can create a real product and attach it to a live show', () async {
    final stream = await goLive();
    await LocalStore.setSessionToken('host-sess');
    await LocalStore.setUserJson(jsonEncode(seller.toJson()));
    final created = await LocalCommerceStore.createProduct(
      user: seller,
      name: 'Live drop sneakers',
      description: 'Added while live with real stock',
      category: 'fashion',
      priceGhs: 220,
      stock: 4,
      images: const ['a', 'b', 'c'],
    );
    expect(created.stock, 4);

    final live = LiveRepository(ApiClient());
    final withProduct = await live.addProducts(stream.id, [created.id]);
    final pinned = await live.pinProduct(stream.id, created.id);
    expect(withProduct.productIds, contains(created.id));
    expect(pinned.pinnedProductId, created.id);
    // Seller repo still available for create path used by UI.
    expect(SellerRepository(ApiClient()), isNotNull);
  });

  test('fresher cloud auction wins over stale host copy', () {
    final stale = LiveAuction(
      id: 'a1',
      productId: 'p1',
      startingBidGhs: 50,
      currentBidGhs: 50,
      minIncrementGhs: 5,
      endsAt: DateTime.now().toUtc().add(const Duration(seconds: 20)).toIso8601String(),
      status: 'open',
    );
    final fresh = stale.copyWith(
      currentBidGhs: 80,
      bidderCount: 2,
      highestBidder: 'Kojo Bidder',
      highestBidderId: 'buyer-1',
    );
    final preferred =
        LocalCommerceStore.preferFresherAuction(stale, fresh);
    expect(preferred?.currentBidGhs, 80);
    expect(preferred?.highestBidder, 'Kojo Bidder');
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
    expect(ended.needsFinalize, isFalse); // no highest bidder
  });


  test('closed unsold auctions stay on Auctions; sold do not (no history dump)', () async {
    final stream = await goLive();
    final open = stream.auction!;
    expect(open.remainsOnAuctions, isTrue);

    final closed = open.copyWith(status: 'closed');
    expect(closed.isSold, isFalse);
    expect(closed.remainsOnAuctions, isTrue);

    final reserve = open.copyWith(status: 'reserve_not_met');
    expect(reserve.remainsOnAuctions, isTrue);

    final sold = open.copyWith(status: 'sold', orderId: 'ord_1');
    expect(sold.isSold, isTrue);
    expect(sold.remainsOnAuctions, isFalse);

    await LocalCommerceStore.updateStream(stream.id, end: true);
    final endedShow = LocalCommerceStore.getStream(stream.id)!;
    expect(endedShow.auction?.status, 'closed');
    expect(endedShow.auction?.remainsOnAuctions, isTrue);
    expect(endedShow.isLiveAuction, isFalse);
    expect(LocalCommerceStore.getProduct(open.productId), isNotNull);
  });

  test('isLiveAuction is only true for an open auction on a live show', () async {
    final stream = await goLive();
    expect(stream.isLive, isTrue);
    expect(stream.auction?.isOpen, isTrue);
    expect(stream.isLiveAuction, isTrue);

    await LocalCommerceStore.updateStream(stream.id, end: true);
    expect(LocalCommerceStore.getStream(stream.id)!.isLiveAuction, isFalse);
  });
}