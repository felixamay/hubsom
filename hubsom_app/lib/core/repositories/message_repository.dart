import 'dart:convert';

import '../../models/message.dart';
import '../../models/user.dart';
import '../services/api_client.dart';
import '../services/api_response.dart';
import '../services/local_message_store.dart';
import '../services/local_store.dart';

class MessageRepository {
  MessageRepository(this._api);

  final ApiClient _api;

  HubsomUser? _currentUser() {
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

  Future<List<ConversationPreview>> listConversations() async {
    await LocalMessageStore.mergeCloud();
    final me = _currentUser();
    try {
      final res = await _api.get('/api/messages');
      final list = ApiResponse.asList(res.data, key: 'conversations');
      if (list.isNotEmpty) {
        return list
            .map(
              (e) => ConversationPreview.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      }
    } catch (_) {}
    if (me == null) return const [];
    return LocalMessageStore.conversationsFor(me.id);
  }

  Future<List<DirectMessage>> thread(String userId) async {
    await LocalMessageStore.mergeCloud();
    final me = _currentUser();
    try {
      final res = await _api.get('/api/messages/$userId');
      final list = ApiResponse.asList(res.data, key: 'messages');
      if (list.isNotEmpty) {
        return list
            .map(
              (e) => DirectMessage.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      }
    } catch (_) {}
    if (me == null) return const [];
    return LocalMessageStore.thread(me.id, userId);
  }

  Future<DirectMessage> send(
    String userId,
    String text, {
    String? toUserName,
  }) async {
    final me = _currentUser();
    if (me == null) throw StateError('Sign in to send messages');
    try {
      final res = await _api.post(
        '/api/messages/$userId',
        data: {'text': text},
      );
      final data = ApiResponse.asMap(res.data);
      if (data != null && data['id'] != null) {
        final msg = DirectMessage.fromJson(data);
        await LocalMessageStore.upsert(msg);
        return msg;
      }
    } catch (_) {}
    return LocalMessageStore.send(
      from: me,
      toUserId: userId,
      text: text,
      toUserName: toUserName,
    );
  }

  Future<void> markThreadRead(String peerUserId) async {
    final me = _currentUser();
    if (me == null) return;
    await LocalMessageStore.markThreadRead(meId: me.id, peerId: peerUserId);
  }

  int unreadCount() {
    final me = _currentUser();
    if (me == null) return 0;
    return LocalMessageStore.unreadCountFor(me.id);
  }

  String peerName(String peerUserId) =>
      LocalMessageStore.resolvePeerName(peerUserId);
}
