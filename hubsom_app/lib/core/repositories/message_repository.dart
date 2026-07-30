import '../../models/message.dart';
import '../services/api_client.dart';

class MessageRepository {
  MessageRepository(this._api);

  final ApiClient _api;

  Future<List<ConversationPreview>> listConversations() async {
    final res = await _api.get<dynamic>('/api/messages');
    final data = res.data;
    final list = data is List
        ? data
        : (data is Map && data['conversations'] is List)
            ? data['conversations'] as List
            : <dynamic>[];
    return list
        .map((e) => ConversationPreview.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<DirectMessage>> thread(String userId) async {
    final res = await _api.get<dynamic>('/api/messages/$userId');
    final data = res.data;
    final list = data is List
        ? data
        : (data is Map && data['messages'] is List)
            ? data['messages'] as List
            : <dynamic>[];
    return list
        .map((e) => DirectMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<DirectMessage> send(String userId, String text) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/messages/$userId',
      data: {'text': text},
    );
    return DirectMessage.fromJson(res.data ?? {});
  }
}
