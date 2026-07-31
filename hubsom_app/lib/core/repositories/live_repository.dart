import '../../models/stream.dart';
import '../data/demo_catalog.dart';
import '../services/api_client.dart';
import '../services/api_response.dart';

class LiveRepository {
  LiveRepository(this._api);

  final ApiClient _api;

  Future<List<LiveStream>> listStreams({String? status}) async {
    try {
      final res = await _api.get(
        '/api/streams',
        queryParameters: {if (status != null) 'status': status},
      );
      final list = ApiResponse.asList(res.data, key: 'streams');
      final parsed = list
          .map((e) => LiveStream.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return parsed.isEmpty ? DemoCatalog.streams : parsed;
    } catch (_) {
      return DemoCatalog.streams;
    }
  }

  Future<LiveStream?> getStream(String id) async {
    try {
      final res = await _api.get('/api/streams/$id');
      final data = ApiResponse.asMap(res.data);
      if (data == null) {
        return DemoCatalog.streams.where((s) => s.id == id).firstOrNull;
      }
      return LiveStream.fromJson(data);
    } catch (_) {
      return DemoCatalog.streams.where((s) => s.id == id).firstOrNull;
    }
  }

  Future<LiveStream> createStream(Map<String, dynamic> body) async {
    final res = await _api.post('/api/streams', data: body);
    final data = ApiResponse.asMap(res.data);
    if (data == null) throw StateError('Create stream failed');
    return LiveStream.fromJson(data);
  }

  Future<void> endStream(String id) async {
    await _api.post('/api/streams/$id/end');
  }

  Future<List<ChatMessage>> listChat(String streamId) async {
    final res = await _api.get('/api/streams/$streamId/chat');
    return ApiResponse.asList(res.data, key: 'messages')
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ChatMessage> sendChat(String streamId, String text) async {
    final res = await _api.post(
      '/api/streams/$streamId/chat',
      data: {'text': text},
    );
    final data = ApiResponse.asMap(res.data);
    if (data == null) throw StateError('Send chat failed');
    return ChatMessage.fromJson(data);
  }

  Future<void> sendReaction(String streamId, String emoji) async {
    await _api.post(
      '/api/streams/$streamId/reactions',
      data: {'emoji': emoji},
    );
  }

  Future<LiveAuction> placeBid(String auctionId, double amountGhs) async {
    final res = await _api.post(
      '/api/auctions/$auctionId/bid',
      data: {'amountGhs': amountGhs},
    );
    final data = ApiResponse.asMap(res.data);
    if (data == null) throw StateError('Bid failed');
    return LiveAuction.fromJson(data);
  }

  Future<Map<String, dynamic>> analytics(String streamId) async {
    final res = await _api.get('/api/streams/$streamId/analytics');
    return ApiResponse.asMap(res.data) ?? {};
  }
}
