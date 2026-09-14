import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/stream.dart';
import 'cloud_store.dart';
import 'firebase_bootstrap.dart';

/// Shared live chat.
///
/// Messages used to live only in the sender's own local storage, so a viewer
/// typing in a show was the only person who ever saw it. They are now real
/// documents that every device in the room reads, pushed as they arrive.
class LiveChatStore {
  LiveChatStore._();

  static const collection = 'liveChat';

  /// Keep the room readable and the payload small on a slow connection.
  static const maxMessages = 200;

  static bool get canWatch => _db != null;

  static String docId(String streamId, String messageId) =>
      '${streamId}__$messageId';

  static Map<String, dynamic> _row(ChatMessage msg) => {
        ...msg.toJson(),
        'id': docId(msg.streamId, msg.id),
        // The message id without the stream prefix, so it round-trips.
        'messageId': msg.id,
        'sentAt': _sentAt(msg.createdAt),
      };

  /// Sortable timestamp. `createdAt` is an ISO string, which orders correctly
  /// as text but is awkward to index, so store epoch millis alongside it.
  static int _sentAt(String createdAt) =>
      DateTime.tryParse(createdAt)?.millisecondsSinceEpoch ?? 0;

  static ChatMessage? _parse(Map<String, dynamic> row) {
    try {
      final messageId = '${row['messageId'] ?? ''}';
      return ChatMessage.fromJson({
        ...row,
        'id': messageId.isNotEmpty ? messageId : '${row['id'] ?? ''}',
      });
    } catch (_) {
      return null;
    }
  }

  static Future<void> send(ChatMessage msg) async {
    if (msg.streamId.isEmpty) return;
    await CloudStore.upsertDocs(collection, [_row(msg)]);
  }

  /// Newest first, matching how the room renders its chat list.
  static Future<List<ChatMessage>> listForStream(String streamId) async {
    if (streamId.isEmpty || !CloudStore.useNetwork) return const [];
    final sdk = _db;
    if (sdk != null) {
      try {
        // Deliberately no orderBy: combining it with the streamId filter needs
        // a composite index, and this project ships none. Sorting happens below.
        final snap = await sdk
            .collection(collection)
            .where('streamId', isEqualTo: streamId)
            .get()
            .timeout(const Duration(seconds: 20));
        return _fromDocs(snap.docs.map((d) => d.data()));
      } catch (e) {
        if (kDebugMode) debugPrint('LiveChatStore.list sdk: $e');
      }
    }
    final rows = await CloudStore.queryDocs(
      collection,
      field: 'streamId',
      value: streamId,
    );
    return _fromDocs(rows);
  }

  /// Push new messages as they are written by anyone in the room.
  static Stream<List<ChatMessage>> watchForStream(String streamId) {
    final sdk = _db;
    if (sdk == null || streamId.isEmpty) return const Stream.empty();
    return sdk
        .collection(collection)
        .where('streamId', isEqualTo: streamId)
        .snapshots()
        .map((snap) => _fromDocs(snap.docs.map((d) => d.data())))
        .handleError((_) {});
  }

  static List<ChatMessage> _fromDocs(Iterable<Map<String, dynamic>> rows) {
    final byId = <String, ChatMessage>{};
    for (final raw in rows) {
      final msg = _parse(Map<String, dynamic>.from(raw));
      if (msg == null || msg.id.isEmpty) continue;
      byId[msg.id] = msg;
    }
    return sortNewestFirst(byId.values);
  }

  /// Newest first, with a stable tie-break so two messages sent in the same
  /// millisecond do not swap places between rebuilds.
  static List<ChatMessage> sortNewestFirst(Iterable<ChatMessage> messages) {
    final list = messages.toList()
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        if (byTime != 0) return byTime;
        return b.id.compareTo(a.id);
      });
    if (list.length > maxMessages) return list.sublist(0, maxMessages);
    return list;
  }

  /// Merge what this device knows with what the cloud has, newest first.
  static List<ChatMessage> merge(
    Iterable<ChatMessage> local,
    Iterable<ChatMessage> cloud,
  ) {
    final byId = <String, ChatMessage>{};
    for (final m in local) {
      if (m.id.isNotEmpty) byId[m.id] = m;
    }
    for (final m in cloud) {
      if (m.id.isEmpty) continue;
      // A moderated cloud copy should win over a stale local one.
      final existing = byId[m.id];
      byId[m.id] = existing != null && existing.moderated ? existing : m;
    }
    return sortNewestFirst(byId.values);
  }

  static FirebaseFirestore? get _db {
    if (!FirebaseBootstrap.ready || !CloudStore.useNetwork) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }
}
