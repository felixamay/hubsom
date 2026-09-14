import 'dart:convert';
import 'dart:typed_data';

import '../../models/live_gift.dart';
import '../../models/stream.dart';
import '../../models/user.dart';
import '../services/api_client.dart';
import '../services/api_response.dart';
import '../services/cloud_media.dart';
import '../services/cloud_store.dart';
import '../services/gift_store.dart';
import '../services/live_chat_store.dart';
import '../services/live_viewer_identity.dart';
import '../services/local_blob_store.dart';
import '../services/local_commerce_store.dart';
import '../services/local_notification_store.dart';
import '../services/local_store.dart';
import '../services/shop_video_cloud.dart';
import 'auth_repository.dart';

class LiveRepository {
  LiveRepository(this._api);

  final ApiClient _api;

  HubsomUser? get _user {
    final raw = LocalStore.userJson;
    if (raw == null || raw.isEmpty) return null;
    try {
      return HubsomUser.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncStream(LiveStream stream) async {
    try {
      final json = stream.toJson();
      final portableCover = await _portableCover(stream.id, stream.cover);
      if (portableCover.isNotEmpty) json['cover'] = portableCover;
      await CloudStore.upsertDocs(CloudStore.streams, [json]);
    } catch (_) {}
  }

  /// Returns a cover URL that every device can load.
  ///
  /// A `hubsom-blob://` ref exists only in this browser's IndexedDB; we resolve
  /// it to a data URL and either inline it (small images) or push it to Storage
  /// (large images). HTTP(S) URLs are returned unchanged.
  Future<String> _portableCover(String streamId, String raw) async {
    if (raw.isEmpty) return raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final dataUrl =
        LocalBlobStore.isRef(raw) ? LocalBlobStore.resolve(raw) : raw;
    if (dataUrl == null || dataUrl.isEmpty) return '';
    if (!dataUrl.startsWith('data:image')) return '';
    // Small enough to embed inline inside the Firestore doc.
    if (dataUrl.length <= shopVideoInlineThumbMaxChars) return dataUrl;
    // Too large to inline — push to Storage and store the https URL instead.
    try {
      final comma = dataUrl.indexOf(',');
      if (comma < 0) return '';
      final bytes = base64Decode(dataUrl.substring(comma + 1));
      final url = await CloudMedia.uploadLiveCover(
        streamId: streamId,
        bytes: Uint8List.fromList(bytes),
      );
      return url ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<List<LiveStream>> listStreams({String? status}) async {
    try {
      final res = await _api.get(
        '/api/streams',
        queryParameters: {if (status != null) 'status': status},
      );
      final list = ApiResponse.asList(res.data, key: 'streams');
      if (list.isNotEmpty) {
        return list
            .map((e) => LiveStream.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {
      // fall through to local / cloud
    }

    final local = LocalCommerceStore.listStreams(status: status);
    try {
      final remoteRows = await CloudStore.listDocs(CloudStore.streams);
      final remote = <LiveStream>[];
      for (final row in remoteRows) {
        try {
          final s = LiveStream.fromJson(row);
          if (status != null && s.status != status) continue;
          remote.add(s);
        } catch (_) {}
      }
      if (remote.isEmpty) return local;
      final byId = <String, LiveStream>{
        for (final s in local) s.id: s,
      };
      for (final s in remote) {
        final existing = byId[s.id];
        byId[s.id] =
            existing == null ? s : LocalCommerceStore.mergeStreams(existing, s);
      }
      final merged = byId.values.toList()
        ..sort((a, b) {
          final aLive = a.isLive ? 0 : 1;
          final bLive = b.isLive ? 0 : 1;
          if (aLive != bLive) return aLive - bLive;
          return (b.startedAt ?? '').compareTo(a.startedAt ?? '');
        });
      return merged;
    } catch (_) {
      return local;
    }
  }

  Future<LiveStream?> _cloudStream(String id) async {
    // Read the one doc. Listing the whole collection to find it made opening a
    // live show slower the more shows had ever been created.
    try {
      final row = await CloudStore.getDoc(CloudStore.streams, id);
      if (row != null && row.isNotEmpty) return LiveStream.fromJson(row);
    } catch (_) {}
    return null;
  }

  Future<LiveStream?> getStream(String id, {bool joinAsViewer = false}) async {
    try {
      final res = await _api.get('/api/streams/$id');
      final data = ApiResponse.asMap(res.data);
      final streamMap = data?['stream'] as Map? ?? data;
      if (streamMap != null && streamMap['id'] != null) {
        return LiveStream.fromJson(Map<String, dynamic>.from(streamMap));
      }
    } catch (_) {
      // fall through
    }

    LiveStream? local = LocalCommerceStore.getStream(id);
    final remote = await _cloudStream(id);

    if (local == null && remote == null) return null;

    if (local == null && remote != null) {
      await LocalCommerceStore.upsertStream(remote);
      local = remote;
    } else if (local != null && remote != null) {
      final merged = LocalCommerceStore.mergeStreams(local, remote);
      if (merged.auction != local.auction ||
          merged.status != local.status ||
          merged.viewerCount != local.viewerCount ||
          !_sameQuantities(
            merged.productQuantities,
            local.productQuantities,
          )) {
        await LocalCommerceStore.upsertStream(merged);
      }
      local = merged;
    }

    if (joinAsViewer && local != null && local.isLive) {
      final user = _user;
      final before = local.viewerCount;
      local = await LocalCommerceStore.joinViewer(
            id,
            viewerId: LiveViewerIdentity.current(userId: user?.id),
            isHost: LiveViewerIdentity.isHost(local, user),
          ) ??
          local;
      // Only push when this join actually changed the audience, so re-entering
      // a room costs nothing.
      if (local.viewerCount != before) await _syncStream(local);
    }
    return local;
  }

  Future<LiveStream> createStream(Map<String, dynamic> body) async {
    try {
      final res = await _api.post('/api/streams', data: body);
      final data = ApiResponse.asMap(res.data);
      final streamMap = data?['stream'] as Map? ?? data;
      if (streamMap != null && streamMap['id'] != null) {
        final stream =
            LiveStream.fromJson(Map<String, dynamic>.from(streamMap));
        await LocalNotificationStore.notifySellerWentLive(stream);
        return stream;
      }
    } catch (_) {
      // fall through to local engine
    }

    final user = _user;
    if (user == null) throw AuthException('Sign in required');
    final cover = '${body['cover'] ?? ''}'.trim();
    if (cover.isEmpty) {
      throw StateError('Add a thumbnail for Watch live and Live now');
    }
    final stream = await LocalCommerceStore.createStream(
      user: user,
      title: body['title'] as String? ?? 'Hubsom Live Show',
      description: body['description'] as String? ?? '',
      cover: cover,
      productIds: (body['productIds'] as List?)?.cast<String>() ?? const [],
      productQuantities: parseProductQuantities(body['productQuantities']),
      pinnedProductId: body['pinnedProductId'] as String?,
      auctionProductId: body['auctionProductId'] as String?,
      startingBidGhs: (body['startingBidGhs'] as num?)?.toDouble() ?? 50,
      askingPriceGhs: (body['askingPriceGhs'] as num?)?.toDouble(),
      auctionDurationSeconds:
          (body['auctionDurationSeconds'] as num?)?.toInt() ?? 30,
      multiHost: body['multiHost'] as bool? ?? false,
    );
    await _syncStream(stream);
    await LocalNotificationStore.notifySellerWentLive(stream);
    return stream;
  }

  Future<LiveStream> endStream(String id) async {
    try {
      final res = await _api.post('/api/streams/$id/end');
      final data = ApiResponse.asMap(res.data);
      final streamMap = data?['stream'] as Map? ?? data;
      if (streamMap != null && streamMap['id'] != null) {
        return LiveStream.fromJson(Map<String, dynamic>.from(streamMap));
      }
    } catch (_) {
      // fall through
    }
    final ended = await LocalCommerceStore.updateStream(id, end: true);
    if (ended == null) throw StateError('Stream not found');
    await _syncStream(ended);
    return ended;
  }

  Future<LiveStream> pinProduct(String streamId, String productId) async {
    try {
      final res = await _api.patch(
        '/api/streams/$streamId',
        data: {'pinnedProductId': productId},
      );
      final data = ApiResponse.asMap(res.data);
      final streamMap = data?['stream'] as Map? ?? data;
      if (streamMap != null && streamMap['id'] != null) {
        return LiveStream.fromJson(Map<String, dynamic>.from(streamMap));
      }
    } catch (_) {
      // fall through
    }
    final updated = await LocalCommerceStore.updateStream(
      streamId,
      pinnedProductId: productId,
    );
    if (updated == null) throw StateError('Stream not found');
    await _syncStream(updated);
    return updated;
  }

  Future<LiveStream> addProducts(
    String streamId,
    List<String> productIds, {
    Map<String, int>? quantities,
  }) async {
    final user = _user;
    if (user == null) throw AuthException('Sign in required');
    final updated = await LocalCommerceStore.addProductsToStream(
      streamId: streamId,
      user: user,
      productIds: productIds,
      quantities: quantities,
    );
    if (updated == null) throw StateError('Stream not found');
    await _syncStream(updated);
    return updated;
  }

  Future<LiveStream> reserveLiveUnit(String streamId, String productId) async {
    final updated = await LocalCommerceStore.decrementLiveQuantity(
      streamId: streamId,
      productId: productId,
    );
    await _syncStream(updated);
    return updated;
  }

  /// Add a listed product to the live bag and start bidding — show stays live.
  Future<LiveStream> startAuction({
    required String streamId,
    required String productId,
    double? startingBidGhs,
    double? askingPriceGhs,
    int durationSeconds = 30,
  }) async {
    final user = _user;
    if (user == null) throw AuthException('Sign in required');
    final updated = await LocalCommerceStore.startAuctionOnLive(
      streamId: streamId,
      user: user,
      productId: productId,
      startingBidGhs: startingBidGhs,
      askingPriceGhs: askingPriceGhs,
      durationSeconds: durationSeconds,
    );
    await _syncStream(updated);
    return updated;
  }

  Future<LiveAuction> extendAuction(String streamId, {int seconds = 30}) async {
    final next = await LocalCommerceStore.extendAuction(
      streamId: streamId,
      seconds: seconds,
    );
    final stream = LocalCommerceStore.getStream(streamId);
    if (stream != null) await _syncStream(stream);
    return next;
  }

  Future<List<ChatMessage>> listChat(String streamId) async {
    try {
      final res = await _api.get('/api/streams/$streamId/chat');
      final list = ApiResponse.asList(res.data, key: 'messages');
      if (list.isNotEmpty) {
        return list
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      if (!ApiResponse.isHtml(res.data) && ApiResponse.decode(res.data) != null) {
        return const [];
      }
    } catch (_) {
      // fall through
    }

    // Chat used to be read from this device only, so a viewer never saw anyone
    // else's messages. Merge in what the room has actually said.
    final local = LocalCommerceStore.listChat(streamId);
    try {
      final cloud = await LiveChatStore.listForStream(streamId);
      if (cloud.isEmpty) return local;
      final merged = LiveChatStore.merge(local, cloud);
      await LocalCommerceStore.cacheChat(streamId, merged);
      return merged;
    } catch (_) {
      return local;
    }
  }

  /// Pushes the room's chat as it is written, so messages land without waiting
  /// for the next refresh.
  Stream<List<ChatMessage>> watchChat(String streamId) =>
      LiveChatStore.watchForStream(streamId);

  bool get canWatchChat => LiveChatStore.canWatch;

  Future<ChatMessage> sendChat(String streamId, String text) async {
    try {
      final res = await _api.post(
        '/api/streams/$streamId/chat',
        data: {'text': text},
      );
      final data = ApiResponse.asMap(res.data);
      final msg = data?['message'] as Map? ?? data;
      if (msg != null && msg['id'] != null) {
        return ChatMessage.fromJson(Map<String, dynamic>.from(msg));
      }
    } catch (_) {
      // fall through
    }
    final user = _user;
    if (user == null) throw AuthException('Sign in required');
    // Publishing to the room happens inside sendChat, so bid and auction
    // notices reach everyone too.
    return LocalCommerceStore.sendChat(
      streamId: streamId,
      user: user,
      text: text,
    );
  }

  Future<LiveReaction> sendReaction(String streamId, String emoji) async {
    try {
      await _api.post(
        '/api/streams/$streamId/reactions',
        data: {'emoji': emoji},
      );
    } catch (_) {
      // ignore remote — always keep local feedback
    }
    return LocalCommerceStore.sendReaction(streamId: streamId, emoji: emoji);
  }

  Future<HubsomUser> buyGiftPoints({
    required String packId,
    required String paymentMethod,
  }) async {
    final user = _user;
    if (user == null) throw AuthException('Sign in required');
    final pack = GiftCatalog.packById(packId);
    if (pack == null) throw StateError('Unknown point pack');
    return GiftStore.buyPoints(
      user: user,
      pack: pack,
      paymentMethod: paymentMethod,
    );
  }

  Future<({HubsomUser user, LiveGift gift})> sendGift({
    required String streamId,
    required String giftId,
  }) async {
    final user = _user;
    if (user == null) throw AuthException('Sign in required');
    final result = await GiftStore.sendGift(
      sender: user,
      streamId: streamId,
      giftId: giftId,
    );
    await LocalCommerceStore.sendChat(
      streamId: streamId,
      user: result.user,
      text:
          'sent a ${result.gift.emoji} ${result.gift.name} (${result.gift.costPoints} pts)',
    );
    await LocalCommerceStore.sendReaction(
      streamId: streamId,
      emoji: result.gift.emoji,
    );
    return (user: result.user, gift: result.gift);
  }

  List<LiveReaction> recentReactions(String streamId) =>
      LocalCommerceStore.recentReactions(streamId);

  Future<LiveAuction> placeBid(String auctionId, double amountGhs) async {
    try {
      final res = await _api.post(
        '/api/auctions/$auctionId/bid',
        data: {'amountGhs': amountGhs},
      );
      final data = ApiResponse.asMap(res.data);
      final auction = data?['auction'] as Map? ?? data;
      if (auction != null && auction['id'] != null) {
        return LiveAuction.fromJson(Map<String, dynamic>.from(auction));
      }
    } catch (_) {
      // fall through
    }
    final user = _user;
    if (user == null) throw AuthException('Sign in required');

    // Ensure the live show is local (viewer may have only seen cloud copy).
    var stream = LocalCommerceStore.findStreamByAuction(auctionId);
    if (stream == null) {
      final rows = await CloudStore.listDocs(CloudStore.streams);
      for (final row in rows) {
        try {
          final s = LiveStream.fromJson(row);
          if (s.auction?.id == auctionId) {
            await LocalCommerceStore.upsertStream(s);
            stream = s;
            break;
          }
        } catch (_) {}
      }
    }

    final next = await LocalCommerceStore.placeBid(
      auctionId: auctionId,
      amountGhs: amountGhs,
      bidder: user,
    );
    stream = LocalCommerceStore.findStreamByAuction(auctionId);
    if (stream != null) await _syncStream(stream);
    return next;
  }

  /// Close a finished auction and create a seller order for the winner.
  Future<LiveStream?> finalizeAuctionIfNeeded(String streamId) async {
    // Pull freshest cloud auction first so host/viewer agree on winner.
    await getStream(streamId);
    final order = await LocalCommerceStore.finalizeAuction(streamId);
    final stream = LocalCommerceStore.getStream(streamId);
    if (stream != null) await _syncStream(stream);
    if (order != null) {
      // Order already cloud-synced via LocalHuberStore.saveOrder.
    }
    return stream;
  }

  Future<Map<String, dynamic>> analytics(String streamId) async {
    try {
      final res = await _api.get('/api/streams/$streamId/analytics');
      final data = ApiResponse.asMap(res.data);
      if (data != null) return data;
    } catch (_) {
      // fall through
    }
    final s = LocalCommerceStore.getStream(streamId);
    if (s == null) return {};
    return {
      'viewerCount': s.viewerCount,
      'peakViewers': s.peakViewers,
      'status': s.status,
      'chatCount': LocalCommerceStore.listChat(streamId).length,
      'giftCount': GiftStore.listLedger()
          .where((e) => e.kind == 'send' && e.streamId == streamId)
          .length,
    };
  }
}

bool _sameQuantities(Map<String, int> a, Map<String, int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
