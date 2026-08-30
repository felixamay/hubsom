import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../models/product.dart';
import '../../models/seller.dart';
import '../../models/stream.dart';
import '../../models/user.dart';
import 'local_store.dart';

/// Device-local products / sellers / live shows when Firebase Hosting has no API.
class LocalCommerceStore {
  LocalCommerceStore._();

  static const _productsKey = 'localProducts';
  static const _sellersKey = 'localSellers';
  static const _streamsKey = 'localStreams';
  static const _chatKey = 'localChat';
  static const _reactionsKey = 'localReactions';
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

    LiveAuction? auction;
    if (auctionProductId != null && owned.contains(auctionProductId)) {
      final product = getProduct(auctionProductId)!;
      final start = startingBidGhs > 0 ? startingBidGhs : product.priceGhs * 0.5;
      auction = LiveAuction(
        id: 'auction-${_uuid.v4().substring(0, 8)}',
        productId: auctionProductId,
        startingBidGhs: start,
        currentBidGhs: start,
        minIncrementGhs: (start * 0.05).clamp(5, 50),
        endsAt: DateTime.now()
            .add(const Duration(hours: 2))
            .toUtc()
            .toIso8601String(),
        status: 'open',
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
        followingSellerIds: user.followingSellerIds,
        savedProductIds: user.savedProductIds,
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
      );
    }
    streams[idx] = s;
    await _saveStreams(streams);
    return s;
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
    final min = auction.currentBidGhs + auction.minIncrementGhs;
    if (amountGhs < min) {
      throw StateError('Bid must be at least $min GHS');
    }
    final next = auction.copyWith(
      currentBidGhs: amountGhs,
      bidderCount: auction.bidderCount + 1,
      highestBidder: bidder.name,
    );
    await updateStream(stream.id, auction: next);
    await sendChat(
      streamId: stream.id,
      user: bidder,
      text: 'Bid ${amountGhs.toStringAsFixed(0)} GHS on auction',
    );
    return next;
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
