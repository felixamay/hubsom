import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../models/order.dart';
import '../../models/product.dart';
import '../../models/product_social.dart';
import '../../models/seller.dart';
import '../../models/stream.dart';
import '../../models/user.dart';
import 'cloud_store.dart';
import 'local_huber_store.dart';
import 'local_store.dart';

/// Device-local products / sellers / live shows when Firebase Hosting has no API.
class LocalCommerceStore {
  LocalCommerceStore._();

  static const _productsKey = 'localProducts';
  static const _sellersKey = 'localSellers';
  static const _streamsKey = 'localStreams';
  static const _chatKey = 'localChat';
  static const _reactionsKey = 'localReactions';
  static const _commentsKey = 'localProductComments';
  static const _likesKey = 'localProductLikes';
  static const _timelineKey = 'localTimelinePosts';
  static const _uuid = Uuid();

  /// Wipe local commerce (keeps auth vault / cart / session).
  static Future<void> clearDemoAndCommerce() async {
    await LocalStore.remove(_productsKey);
    await LocalStore.remove(_sellersKey);
    await LocalStore.remove(_streamsKey);
    await LocalStore.remove(_chatKey);
    await LocalStore.remove(_reactionsKey);
    await LocalStore.remove('cache_products');
  }

  /// One-time wipe of previously seeded demo catalog / live shows.
  static Future<void> migrateClearDemoOnce() async {
    const flag = 'commerce_cleared_v2';
    if (LocalStore.getBool(flag)) return;
    await clearDemoAndCommerce();
    await LocalStore.setBool(flag, true);
  }

  // --- sellers ---

  static List<Seller> listSellers() {
    return _readList(_sellersKey)
        .map((e) => Seller.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Seller? getSeller(String idOrSlug) {
    for (final s in listSellers()) {
      if (s.id == idOrSlug || s.slug == idOrSlug) return s;
    }
    return null;
  }

  static Future<Seller> ensureSellerForUser(HubsomUser user) async {
    final sellers = listSellers();
    for (final s in sellers) {
      if (s.ownerUserId == user.id ||
          (user.sellerId != null && s.id == user.sellerId)) {
        return s;
      }
    }

    final id = user.sellerId?.isNotEmpty == true
        ? user.sellerId!
        : 'seller-${user.id}';
    final slug = id.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '-').toLowerCase();
    final seller = Seller(
      id: id,
      slug: slug,
      name: user.name.isNotEmpty ? '${user.name} Store' : 'My Hubsom Store',
      city: user.city ?? 'Accra',
      region: user.region ?? 'Greater Accra',
      bio: user.bio ?? 'Selling live on Hubsom',
      avatar: user.image ?? '',
      cover: '',
      ownerUserId: user.id,
      categories: const [],
    );
    sellers.add(seller);
    await _writeList(_sellersKey, sellers.map((s) => s.toJson()).toList());
    return seller;
  }

  static Future<Seller> upsertSeller(Seller seller) async {
    final sellers = listSellers();
    final idx = sellers.indexWhere((s) => s.id == seller.id);
    if (idx >= 0) {
      sellers[idx] = seller;
    } else {
      sellers.add(seller);
    }
    await _writeList(_sellersKey, sellers.map((s) => s.toJson()).toList());
    return seller;
  }

  // --- products ---

  static List<Product> listProducts({
    String? category,
    String? q,
    String? sellerId,
  }) {
    var list = _readList(_productsKey)
        .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (category != null && category.isNotEmpty) {
      list = list.where((p) => p.category == category).toList();
    }
    if (sellerId != null && sellerId.isNotEmpty) {
      list = list.where((p) => p.sellerId == sellerId).toList();
    }
    if (q != null && q.trim().isNotEmpty) {
      final needle = q.trim().toLowerCase();
      list = list
          .where(
            (p) =>
                p.name.toLowerCase().contains(needle) ||
                p.description.toLowerCase().contains(needle) ||
                p.tags.any((t) => t.toLowerCase().contains(needle)),
          )
          .toList();
    }
    return list;
  }

  static Product? getProduct(String idOrSlug) {
    for (final p in listProducts()) {
      if (p.id == idOrSlug || p.slug == idOrSlug) return p;
    }
    return null;
  }

  static Future<Product> createProduct({
    required HubsomUser user,
    required String name,
    required String description,
    required String category,
    required double priceGhs,
    required int stock,
    List<String> images = const [],
    List<String> supports = const [
      'buy-now',
      'store-listing',
      'live-selling',
      'live-auction',
    ],
    bool hasDemoVideo = false,
    String? demoVideoUrl,
  }) async {
    if (images.length < 3) {
      throw StateError('Upload at least 3 product photos before publishing');
    }
    final seller = await ensureSellerForUser(user);
    final id = 'prod-${_uuid.v4().substring(0, 8)}';
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final product = Product(
      id: id,
      slug: slug.isEmpty ? id : slug,
      name: name,
      description: description,
      category: category,
      priceGhs: priceGhs,
      images: images,
      sellerId: seller.id,
      stock: stock,
      supports: supports,
      hasDemoVideo: hasDemoVideo,
      demoVideoUrl: demoVideoUrl,
    );
    final products = listProducts();
    products.insert(0, product);
    await _writeList(_productsKey, products.map((p) => p.toJson()).toList());
    return product;
  }

  // --- streams ---

  static List<LiveStream> listStreams({String? status}) {
    var list = _readList(_streamsKey)
        .map((e) => LiveStream.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (status != null) {
      list = list.where((s) => s.status == status).toList();
    }
    list.sort((a, b) {
      final aLive = a.isLive ? 0 : 1;
      final bLive = b.isLive ? 0 : 1;
      if (aLive != bLive) return aLive - bLive;
      return (b.startedAt ?? '').compareTo(a.startedAt ?? '');
    });
    return list;
  }

  static LiveStream? getStream(String id) {
    for (final s in listStreams()) {
      if (s.id == id) return s;
    }
    return null;
  }

  static Future<LiveStream> upsertStream(LiveStream stream) async {
    final streams = listStreams();
    final idx = streams.indexWhere((s) => s.id == stream.id);
    if (idx >= 0) {
      streams[idx] = stream;
    } else {
      streams.insert(0, stream);
    }
    await _saveStreams(streams);
    return stream;
  }

  /// Prefer the auction with the freshest bids / sold order.
  static LiveAuction? preferFresherAuction(LiveAuction? a, LiveAuction? b) {
    if (a == null) return b;
    if (b == null) return a;
    if (b.orderId != null && a.orderId == null) return b;
    if (a.orderId != null && b.orderId == null) return a;
    if (b.status == 'sold' && a.status != 'sold') return b;
    if (a.status == 'sold' && b.status != 'sold') return a;
    if (b.status == 'open' && a.status == 'reserve_not_met') return b;
    if (a.status == 'open' && b.status == 'reserve_not_met') return a;
    if (b.currentBidGhs > a.currentBidGhs + 0.001) return b;
    if (a.currentBidGhs > b.currentBidGhs + 0.001) return a;
    if (b.bidderCount > a.bidderCount) return b;
    if (a.bidderCount > b.bidderCount) return a;
    if (b.endsAt.compareTo(a.endsAt) > 0) return b;
    if (a.endsAt.compareTo(b.endsAt) > 0) return a;
    if (b.recentBids.length > a.recentBids.length) return b;
    return a;
  }

  static LiveStream mergeStreams(LiveStream local, LiveStream remote) {
    final auction = preferFresherAuction(local.auction, remote.auction);
    final preferRemoteEnded = !remote.isLive && local.isLive;
    final viewers = remote.viewerCount > local.viewerCount
        ? remote.viewerCount
        : local.viewerCount;
    final products = <String>{...local.productIds, ...remote.productIds}.toList();
    return local.copyWith(
      status: preferRemoteEnded ? remote.status : local.status,
      endedAt: preferRemoteEnded ? remote.endedAt : local.endedAt,
      viewerCount: viewers,
      peakViewers: viewers > local.peakViewers ? viewers : local.peakViewers,
      pinnedProductId: remote.pinnedProductId ?? local.pinnedProductId,
      productIds: products,
      auction: auction,
      replayAvailable: remote.replayAvailable || local.replayAvailable,
    );
  }

  static LiveStream? findStreamByAuction(String auctionId) {
    for (final s in listStreams()) {
      if (s.auction?.id == auctionId) return s;
    }
    return null;
  }

  static Future<void> _saveStreams(List<LiveStream> streams) async {
    await _writeList(_streamsKey, streams.map((s) => s.toJson()).toList());
  }

  static Future<LiveStream> createStream({
    required HubsomUser user,
    required String title,
    String description = '',
    required List<String> productIds,
    String? pinnedProductId,
    String? auctionProductId,
    double startingBidGhs = 50,
    double? askingPriceGhs,
    int auctionDurationSeconds = 30,
    bool multiHost = false,
  }) async {
    if (productIds.isEmpty) {
      throw StateError('Select at least one of your products for the show');
    }
    final seller = await ensureSellerForUser(user);
    final owned = productIds
        .where((id) => getProduct(id)?.sellerId == seller.id)
        .toList();
    if (owned.isEmpty) {
      throw StateError('Select at least one of your products for the show');
    }

    final pin = pinnedProductId != null && owned.contains(pinnedProductId)
        ? pinnedProductId
        : owned.first;

    final durationSecs = auctionDurationSeconds.clamp(1, 30);

    LiveAuction? auction;
    if (auctionProductId != null && owned.contains(auctionProductId)) {
      final product = getProduct(auctionProductId)!;
      final start = startingBidGhs > 0 ? startingBidGhs : product.priceGhs * 0.5;
      final ask = askingPriceGhs != null && askingPriceGhs > 0
          ? askingPriceGhs
          : product.priceGhs;
      auction = LiveAuction(
        id: 'auction-${_uuid.v4().substring(0, 8)}',
        productId: auctionProductId,
        startingBidGhs: start,
        currentBidGhs: start,
        minIncrementGhs: (start * 0.05).clamp(1, 50),
        endsAt: DateTime.now()
            .add(Duration(seconds: durationSecs))
            .toUtc()
            .toIso8601String(),
        status: 'open',
        askingPriceGhs: ask,
      );
    }

    final id = 'live-${_uuid.v4().substring(0, 8)}';
    final now = DateTime.now().toUtc().toIso8601String();
    final stream = LiveStream(
      id: id,
      title: title.trim().isEmpty ? 'Hubsom Live Show' : title.trim(),
      description: description.trim(),
      sellerId: seller.id,
      status: 'live',
      channelName: 'hubsom-$id',
      cover: getProduct(pin)?.images.isNotEmpty == true
          ? getProduct(pin)!.images.first
          : '',
      viewerCount: 1,
      peakViewers: 1,
      startedAt: now,
      productIds: owned,
      pinnedProductId: pin,
      hosts: [
        StreamHost(
          id: user.id,
          name: user.name,
          role: 'host',
          avatar: user.image ?? '',
        ),
      ],
      auction: auction,
      categories: {
        for (final id in owned)
          if (getProduct(id) != null) getProduct(id)!.category,
      }.toList(),
      isMultiHost: multiHost,
    );

    final streams = listStreams();
    streams.insert(0, stream);
    await _saveStreams(streams);

    // Keep session sellerId in sync for host-mode checks.
    if (user.sellerId != seller.id) {
      final patched = HubsomUser(
        id: user.id,
        email: user.email,
        name: user.name,
        image: user.image,
        phone: user.phone,
        city: user.city,
        region: user.region,
        bio: user.bio,
        role: user.role == 'buyer' ? 'both' : user.role,
        sellerId: seller.id,
        huberId: user.huberId,
      followingSellerIds: user.followingSellerIds,
      savedProductIds: user.savedProductIds,
      likedProductIds: user.likedProductIds,
      addresses: user.addresses,
        emailVerified: user.emailVerified,
        walletBalanceGhs: user.walletBalanceGhs,
      );
      await LocalStore.setUserJson(jsonEncode(patched.toJson()));
    }
    return stream;
  }

  static Future<LiveStream?> updateStream(
    String id, {
    String? pinnedProductId,
    String? status,
    int? viewerCount,
    LiveAuction? auction,
    List<String>? productIds,
    bool end = false,
  }) async {
    final streams = listStreams();
    final idx = streams.indexWhere((s) => s.id == id);
    if (idx < 0) return null;
    var s = streams[idx];
    if (end) {
      s = s.copyWith(
        status: 'ended',
        endedAt: DateTime.now().toUtc().toIso8601String(),
        auction: s.auction?.copyWith(status: 'closed'),
        replayAvailable: true,
      );
    } else {
      final viewers = viewerCount ?? s.viewerCount;
      s = s.copyWith(
        pinnedProductId: pinnedProductId,
        status: status,
        viewerCount: viewers,
        peakViewers: viewers > s.peakViewers ? viewers : s.peakViewers,
        auction: auction,
        productIds: productIds,
      );
    }
    streams[idx] = s;
    await _saveStreams(streams);
    return s;
  }

  static Future<LiveStream?> addProductsToStream({
    required String streamId,
    required HubsomUser user,
    required List<String> productIds,
  }) async {
    final stream = getStream(streamId);
    if (stream == null || !stream.isLive) {
      throw StateError('Live show not found');
    }
    final seller = await ensureSellerForUser(user);
    if (stream.sellerId != seller.id) {
      throw StateError('Only the host can add products');
    }
    final owned = productIds
        .where((id) => getProduct(id)?.sellerId == seller.id)
        .toList();
    if (owned.isEmpty) {
      throw StateError('Select products from your catalog');
    }
    final merged = <String>{...stream.productIds, ...owned}.toList();
    return updateStream(streamId, productIds: merged);
  }

  /// Restart the auction clock (e.g. when asking price was not met).
  static Future<LiveAuction> extendAuction({
    required String streamId,
    int seconds = 30,
  }) async {
    final stream = getStream(streamId);
    if (stream == null || stream.auction == null) {
      throw StateError('Auction not found');
    }
    if (!stream.isLive) throw StateError('Show has ended');
    final auction = stream.auction!;
    if (auction.orderId != null || auction.status == 'sold') {
      throw StateError('Auction already sold');
    }
    final secs = seconds.clamp(5, 30);
    final next = auction.copyWith(
      status: 'open',
      endsAt: DateTime.now()
          .add(Duration(seconds: secs))
          .toUtc()
          .toIso8601String(),
    );
    await updateStream(streamId, auction: next);
    return next;
  }

  static Future<LiveStream?> joinViewer(String id) async {
    final s = getStream(id);
    if (s == null || !s.isLive) return s;
    return updateStream(id, viewerCount: s.viewerCount + 1);
  }

  static Future<LiveAuction> placeBid({
    required String auctionId,
    required double amountGhs,
    required HubsomUser bidder,
  }) async {
    final stream = findStreamByAuction(auctionId);
    if (stream == null || stream.auction == null) {
      throw StateError('Auction not found');
    }
    if (!stream.isLive) throw StateError('Show has ended');
    final auction = stream.auction!;
    if (auction.status != 'open') throw StateError('Auction is closed');

    final now = DateTime.now().toUtc();
    DateTime endsAt;
    try {
      endsAt = DateTime.parse(auction.endsAt).toUtc();
    } catch (_) {
      endsAt = now.add(const Duration(hours: 1));
    }
    if (endsAt.isBefore(now)) {
      throw StateError('Auction has ended');
    }

    final min = auction.currentBidGhs + auction.minIncrementGhs;
    if (amountGhs + 0.001 < min) {
      throw StateError('Bid must be at least ${min.toStringAsFixed(0)} GHS');
    }

    // Soft close: late bids nudge the clock so short auctions stay fair.
    if (endsAt.difference(now).inSeconds < 3) {
      endsAt = now.add(const Duration(seconds: 5));
    }

    final bid = AuctionBid(
      bidderName: bidder.name,
      amountGhs: amountGhs,
      at: now.toIso8601String(),
      bidderId: bidder.id,
    );
    final recent = [bid, ...auction.recentBids].take(12).toList();
    final next = auction.copyWith(
      currentBidGhs: amountGhs,
      bidderCount: auction.bidderCount + 1,
      highestBidder: bidder.name,
      highestBidderId: bidder.id,
      highestBidderEmail: bidder.email,
      endsAt: endsAt.toIso8601String(),
      recentBids: recent,
    );
    await updateStream(stream.id, auction: next);
    await sendChat(
      streamId: stream.id,
      user: bidder,
      text: '🔥 Bid ${amountGhs.toStringAsFixed(0)} GHS — leading now',
    );
    return next;
  }

  /// When the auction clock hits zero with a winner, create a seller order once.
  static Future<Order?> finalizeAuction(String streamId) async {
    final stream = getStream(streamId);
    if (stream == null || stream.auction == null) return null;
    var auction = stream.auction!;

    if (auction.orderId != null) {
      for (final o in LocalHuberStore.listOrders()) {
        if (o.id == auction.orderId) return o;
      }
      return null;
    }

    // Still counting down.
    if (auction.status == 'open' && auction.isOpen) return null;

    // Asking price not met — mark for seller to extend (no order yet).
    if (!auction.askMet) {
      if (auction.status != 'reserve_not_met') {
        await updateStream(
          streamId,
          auction: auction.copyWith(status: 'reserve_not_met'),
        );
      }
      return null;
    }

    // No winning bidder — just mark closed.
    if (auction.highestBidder == null && auction.highestBidderId == null) {
      await updateStream(
        streamId,
        auction: auction.copyWith(status: 'closed'),
      );
      return null;
    }

    final product = getProduct(auction.productId);
    final orderId = 'ord_auc_${auction.id}';
    // Idempotent if another device already saved this order id.
    for (final o in LocalHuberStore.listOrders()) {
      if (o.id == orderId) {
        await updateStream(
          streamId,
          auction: auction.copyWith(status: 'sold', orderId: orderId),
        );
        return o;
      }
    }

    final price = auction.currentBidGhs;
    final order = Order(
      id: orderId,
      subtotalGhs: price,
      status: 'paid',
      userId: auction.highestBidderId,
      buyerName: auction.highestBidder,
      buyerEmail: auction.highestBidderEmail,
      streamId: streamId,
      lines: [
        OrderLine(
          productId: auction.productId,
          sellerId: stream.sellerId,
          name: product?.name ?? 'Live auction win',
          image: product?.images.isNotEmpty == true ? product!.images.first : null,
          quantity: 1,
          unitPriceGhs: price,
          lineTotalGhs: price,
          category: product?.category ?? 'auction',
        ),
      ],
      shipping: OrderShipping(
        recipientName: auction.highestBidder ?? 'Winner',
        phone: '',
        line1: 'Live auction win — confirm delivery with buyer',
        city: 'Accra',
        region: 'Greater Accra',
        notes: 'Won on Hubsom live auction ${auction.id}',
        label: 'Live auction',
      ),
      paymentMethods: const ['live-auction'],
      deliveryEstimate: 'Arrange with buyer',
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    await LocalHuberStore.saveOrder(order);
    await updateStream(
      streamId,
      auction: auction.copyWith(status: 'sold', orderId: orderId),
    );
    return order;
  }

  // --- chat ---

  static Map<String, List<ChatMessage>> _chatMap() {
    final raw = LocalStore.getString(_chatKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return map.map((k, v) {
        final list = (v as List)
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return MapEntry(k, list);
      });
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveChat(Map<String, List<ChatMessage>> map) async {
    final encoded = map.map(
      (k, v) => MapEntry(k, v.map((m) => m.toJson()).toList()),
    );
    await LocalStore.setString(_chatKey, jsonEncode(encoded));
  }

  static List<ChatMessage> listChat(String streamId) {
    final list = _chatMap()[streamId] ?? [];
    return list.reversed.toList();
  }

  static Future<ChatMessage> sendChat({
    required String streamId,
    required HubsomUser user,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw StateError('Message required');
    final msg = ChatMessage(
      id: 'msg-${_uuid.v4().substring(0, 8)}',
      streamId: streamId,
      userId: user.id,
      displayName: user.name.isNotEmpty ? user.name : 'Viewer',
      text: trimmed,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    final map = _chatMap();
    final list = <ChatMessage>[...(map[streamId] ?? const <ChatMessage>[]), msg];
    map[streamId] = list;
    await _saveChat(map);
    return msg;
  }

  // --- reactions ---

  static Future<LiveReaction> sendReaction({
    required String streamId,
    required String emoji,
  }) async {
    final reaction = LiveReaction(
      id: 'rx-${_uuid.v4().substring(0, 8)}',
      streamId: streamId,
      emoji: emoji,
      x: 0.55 + (DateTime.now().millisecond % 300) / 1000,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    final raw = LocalStore.getString(_reactionsKey);
    final map = raw == null || raw.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final list = List<dynamic>.from(map[streamId] as List? ?? []);
    list.add({
      'id': reaction.id,
      'streamId': reaction.streamId,
      'emoji': reaction.emoji,
      'x': reaction.x,
      'createdAt': reaction.createdAt,
    });
    // Keep last 40
    map[streamId] = list.length > 40 ? list.sublist(list.length - 40) : list;
    await LocalStore.setString(_reactionsKey, jsonEncode(map));
    return reaction;
  }

  static List<LiveReaction> recentReactions(String streamId) {
    final raw = LocalStore.getString(_reactionsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final list = List<dynamic>.from(map[streamId] as List? ?? []);
      return list
          .map((e) => LiveReaction.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // --- product social (like / comment / timeline) ---

  static Map<String, dynamic> _likesMap() {
    final raw = LocalStore.getString(_likesKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveLikesMap(Map<String, dynamic> map) async {
    await LocalStore.setString(_likesKey, jsonEncode(map));
    final rows = <Map<String, dynamic>>[];
    map.forEach((productId, value) {
      if (value is Map) {
        rows.add({
          'id': productId,
          'productId': productId,
          ...Map<String, dynamic>.from(value),
        });
      }
    });
    try {
      await CloudStore.upsertDocs(CloudStore.productLikes, rows);
    } catch (_) {}
  }

  static int likeCount(String productId) {
    final entry = _likesMap()[productId];
    if (entry is Map) {
      return (entry['count'] as num?)?.toInt() ??
          ((entry['userIds'] as List?)?.length ?? 0);
    }
    return 0;
  }

  static bool isLikedBy(String productId, String userId) {
    final entry = _likesMap()[productId];
    if (entry is! Map) return false;
    final ids = (entry['userIds'] as List?)?.map((e) => '$e').toList() ?? [];
    return ids.contains(userId);
  }

  static Future<int> toggleProductLike({
    required String productId,
    required String userId,
  }) async {
    final map = _likesMap();
    final raw = Map<String, dynamic>.from(
      (map[productId] as Map?) ?? {'count': 0, 'userIds': <String>[]},
    );
    final ids = [
      ...(raw['userIds'] as List?)?.map((e) => '$e') ?? const <String>[],
    ];
    if (ids.contains(userId)) {
      ids.remove(userId);
    } else {
      ids.add(userId);
    }
    raw['userIds'] = ids;
    raw['count'] = ids.length;
    map[productId] = raw;
    await _saveLikesMap(map);
    return ids.length;
  }

  static List<ProductComment> listComments(String productId) {
    final list = _readList(_commentsKey)
        .map((e) => ProductComment.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((c) => c.productId == productId)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<ProductComment> addComment({
    required String productId,
    required HubsomUser user,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw StateError('Write a comment first');
    final comment = ProductComment(
      id: 'cmt-${_uuid.v4().substring(0, 8)}',
      productId: productId,
      userId: user.id,
      userName: user.name,
      text: trimmed,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    final rows = _readList(_commentsKey);
    rows.insert(0, comment.toJson());
    await _writeList(_commentsKey, rows);
    try {
      await CloudStore.upsertDocs(CloudStore.productComments, [comment.toJson()]);
    } catch (_) {}
    return comment;
  }

  static List<TimelinePost> listTimelinePosts() {
    final list = _readList(_timelineKey)
        .map((e) => TimelinePost.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<TimelinePost> shareProductToTimeline({
    required Product product,
    required HubsomUser author,
    String caption = '',
  }) async {
    final post = TimelinePost(
      id: 'post-${_uuid.v4().substring(0, 8)}',
      authorId: author.id,
      authorName: author.name,
      productId: product.id,
      productName: product.name,
      productImage: product.images.isNotEmpty ? product.images.first : null,
      caption: caption.trim().isEmpty
          ? 'Check out ${product.name} on Hubsom'
          : caption.trim(),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    final rows = _readList(_timelineKey);
    rows.insert(0, post.toJson());
    await _writeList(_timelineKey, rows);
    try {
      await CloudStore.upsertDocs(CloudStore.timelinePosts, [post.toJson()]);
    } catch (_) {}
    return post;
  }

  static Future<void> mergeCloudSocial() async {
    try {
      final comments = await CloudStore.listDocs(CloudStore.productComments);
      if (comments.isNotEmpty) {
        final byId = <String, Map<String, dynamic>>{
          for (final c in _readList(_commentsKey))
            if (c is Map) '${c['id']}': Map<String, dynamic>.from(c),
        };
        for (final c in comments) {
          byId['${c['id']}'] = c;
        }
        await _writeList(_commentsKey, byId.values.toList());
      }
    } catch (_) {}
    try {
      final posts = await CloudStore.listDocs(CloudStore.timelinePosts);
      if (posts.isNotEmpty) {
        final byId = <String, Map<String, dynamic>>{
          for (final p in _readList(_timelineKey))
            if (p is Map) '${p['id']}': Map<String, dynamic>.from(p),
        };
        for (final p in posts) {
          byId['${p['id']}'] = p;
        }
        await _writeList(_timelineKey, byId.values.toList());
      }
    } catch (_) {}
    try {
      final likes = await CloudStore.listDocs(CloudStore.productLikes);
      if (likes.isNotEmpty) {
        final map = _likesMap();
        for (final row in likes) {
          final id = '${row['productId'] ?? row['id']}';
          if (id.isEmpty || id == 'null') continue;
          map[id] = {
            'count': row['count'] ?? ((row['userIds'] as List?)?.length ?? 0),
            'userIds': row['userIds'] ?? const [],
          };
        }
        await LocalStore.setString(_likesKey, jsonEncode(map));
      }
    } catch (_) {}
  }

  // --- helpers ---

  static List<dynamic> _readList(String key) {
    final raw = LocalStore.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return List<dynamic>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  static Future<void> _writeList(String key, List<dynamic> list) async {
    await LocalStore.setString(key, jsonEncode(list));
  }
}
