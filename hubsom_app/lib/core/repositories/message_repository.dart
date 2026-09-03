import '../../models/message.dart';
import '../services/api_client.dart';
import '../services/api_response.dart';

class MessageRepository {
  MessageRepository(this._api);

  final ApiClient _api;

  Future<List<ConversationPreview>> listConversations() async {
    final res = await _api.get('/api/messages');
    return ApiResponse.asList(res.data, key: 'conversations')
        .map(
          (e) => ConversationPreview.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<DirectMessage>> thread(String userId) async {
    final res = await _api.get('/api/messages/$userId');
    return ApiResponse.asList(res.data, key: 'messages')
        .map((e) => DirectMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<DirectMessage> send(String userId, String text) async {
    final res = await _api.post(
      '/api/messages/$userId',
      data: {'text': text},
    );
    final data = ApiResponse.asMap(res.data);
    if (data == null) throw StateError('Send message failed');
    return DirectMessage.fromJson(data);
  }
}
