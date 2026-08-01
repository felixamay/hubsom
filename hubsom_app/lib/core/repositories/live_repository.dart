import 'dart:convert';

import '../../models/stream.dart';
import '../../models/user.dart';
import '../services/api_client.dart';
import '../services/api_response.dart';
import '../services/local_commerce_store.dart';
import '../services/local_store.dart';
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
      // fall through to local
    }
    return LocalCommerceStore.listStreams(status: status);
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
    if (joinAsViewer) {
      return LocalCommerceStore.joinViewer(id);
    }
    return LocalCommerceStore.getStream(id);
  }

  Future<LiveStream> createStream(Map<String, dynamic> body) async {
    try {
      final res = await _api.post('/api/streams', data: body);
      final data = ApiResponse.asMap(res.data);
      final streamMap = data?['stream'] as Map? ?? data;
      if (streamMap != null && streamMap['id'] != null) {
        return LiveStream.fromJson(Map<String, dynamic>.from(streamMap));
      }
    } catch (_) {
      // fall through to local engine
    }

    final user = _user;
    if (user == null) throw AuthException('Sign in required');
    return LocalCommerceStore.createStream(
      user: user,
      title: body['title'] as String? ?? 'Hubsom Live Show',
      description: body['description'] as String? ?? '',
      productIds: (body['productIds'] as List?)?.cast<String>() ?? const [],
      pinnedProductId: body['pinnedProductId'] as String?,
      auctionProductId: body['auctionProductId'] as String?,
      startingBidGhs: (body['startingBidGhs'] as num?)?.toDouble() ?? 50,
      multiHost: body['multiHost'] as bool? ?? false,
    );
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
    return updated;
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
      // Empty API list is valid — don't mix with local unless HTML/no API.
      if (!ApiResponse.isHtml(res.data) && ApiResponse.decode(res.data) != null) {
        return const [];
      }
    } catch (_) {
      // fall through
    }
    return LocalCommerceStore.listChat(streamId);
  }

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
    return LocalCommerceStore.placeBid(
      auctionId: auctionId,
      amountGhs: amountGhs,
      bidder: user,
    );
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
    };
  }
}
