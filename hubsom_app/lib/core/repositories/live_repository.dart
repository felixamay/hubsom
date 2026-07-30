import '../../models/stream.dart';
import '../services/api_client.dart';

class LiveRepository {
  LiveRepository(this._api);

  final ApiClient _api;

  Future<List<LiveStream>> listStreams({String? status}) async {
    final res = await _api.get<dynamic>(
      '/api/streams',
      queryParameters: {if (status != null) 'status': status},
    );
    final data = res.data;
    final list = data is List
        ? data
        : (data is Map && data['streams'] is List)
            ? data['streams'] as List
            : <dynamic>[];
    return list
        .map((e) => LiveStream.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<LiveStream?> getStream(String id) async {
    final res = await _api.get<Map<String, dynamic>>('/api/streams/$id');
    if (res.data == null) return null;
    return LiveStream.fromJson(res.data!);
  }

  Future<LiveStream> createStream(Map<String, dynamic> body) async {
    final res = await _api.post<Map<String, dynamic>>('/api/streams', data: body);
    return LiveStream.fromJson(res.data ?? {});
  }

  Future<void> endStream(String id) async {
    await _api.post('/api/streams/$id/end');
  }

  Future<List<ChatMessage>> listChat(String streamId) async {
    final res = await _api.get<dynamic>('/api/streams/$streamId/chat');
    final data = res.data;
    final list = data is List
        ? data
        : (data is Map && data['messages'] is List)
            ? data['messages'] as List
            : <dynamic>[];
    return list
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ChatMessage> sendChat(String streamId, String text) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/streams/$streamId/chat',
      data: {'text': text},
    );
    return ChatMessage.fromJson(res.data ?? {});
  }

  Future<void> sendReaction(String streamId, String emoji) async {
    await _api.post(
      '/api/streams/$streamId/reactions',
      data: {'emoji': emoji},
    );
  }

  Future<LiveAuction> placeBid(String auctionId, double amountGhs) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/auctions/$auctionId/bid',
      data: {'amountGhs': amountGhs},
    );
    return LiveAuction.fromJson(res.data ?? {});
  }

  Future<Map<String, dynamic>> analytics(String streamId) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/api/streams/$streamId/analytics',
    );
    return res.data ?? {};
  }
}
