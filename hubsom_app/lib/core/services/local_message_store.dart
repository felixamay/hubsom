import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../models/message.dart';
import '../../models/user.dart';
import 'cloud_store.dart';
import 'local_commerce_store.dart';
import 'local_store.dart';

/// Device + Firestore direct messages between Hubsom users.
class LocalMessageStore {
  LocalMessageStore._();

  static const _key = 'localDirectMessages';
  static const _uuid = Uuid();

  static List<DirectMessage> listAll() {
    final raw = LocalStore.getString(_key);
    if (raw == null || raw.isEmpty) return <DirectMessage>[];
    try {
      final list = List<dynamic>.from(jsonDecode(raw) as List);
      return list
          .map((e) => DirectMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return <DirectMessage>[];
    }
  }

  static Future<void> _save(List<DirectMessage> rows) async {
    await LocalStore.setString(
      _key,
      jsonEncode(rows.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> mergeCloud() async {
    try {
      final remote = await CloudStore.listDocs(CloudStore.directMessages);
      if (remote.isEmpty) return;
      final byId = <String, DirectMessage>{
        for (final m in listAll()) m.id: m,
      };
      for (final row in remote) {
        try {
          final m = DirectMessage.fromJson(row);
          byId[m.id] = m;
        } catch (_) {}
      }
      await _save(byId.values.toList());
    } catch (_) {}
  }

  static List<DirectMessage> forUser(String userId) {
    final list = listAll()
        .where((m) => m.fromUserId == userId || m.toUserId == userId)
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  static List<DirectMessage> thread(String meId, String peerId) {
    final list = listAll()
        .where(
          (m) =>
              (m.fromUserId == meId && m.toUserId == peerId) ||
              (m.fromUserId == peerId && m.toUserId == meId),
        )
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  static String resolvePeerName(String peerId, {String? fallback}) {
    if (fallback != null && fallback.trim().isNotEmpty) return fallback.trim();
    for (final s in LocalCommerceStore.listSellers()) {
      if (s.id == peerId || s.ownerUserId == peerId) return s.name;
    }
    final vault = LocalStore.loadCredentialVault();
    for (final entry in vault.values) {
      if (entry is! Map) continue;
      final uj = entry['userJson'];
      if (uj is! Map) continue;
      try {
        final u = HubsomUser.fromJson(Map<String, dynamic>.from(uj));
        if (u.id == peerId) return u.name;
      } catch (_) {}
    }
    // Scan messages for a stored name.
    for (final m in listAll()) {
      if (m.fromUserId == peerId && m.fromUserName.trim().isNotEmpty) {
        return m.fromUserName;
      }
      if (m.toUserId == peerId && m.toUserName.trim().isNotEmpty) {
        return m.toUserName;
      }
    }
    if (peerId.length <= 8) return peerId;
    return 'User ${peerId.substring(0, 6)}';
  }

  static String? resolvePeerAvatar(String peerId) {
    for (final s in LocalCommerceStore.listSellers()) {
      if (s.id == peerId || s.ownerUserId == peerId) {
        return s.avatar.isEmpty ? null : s.avatar;
      }
    }
    final vault = LocalStore.loadCredentialVault();
    for (final entry in vault.values) {
      if (entry is! Map) continue;
      final uj = entry['userJson'];
      if (uj is! Map) continue;
      try {
        final u = HubsomUser.fromJson(Map<String, dynamic>.from(uj));
        if (u.id == peerId) return u.image;
      } catch (_) {}
    }
    return null;
  }

  static List<ConversationPreview> conversationsFor(String meId) {
    final mine = forUser(meId);
    final latestByPeer = <String, DirectMessage>{};
    final unreadByPeer = <String, int>{};
    for (final m in mine) {
      final peer = m.fromUserId == meId ? m.toUserId : m.fromUserId;
      if (peer.isEmpty || peer == meId) continue;
      final prev = latestByPeer[peer];
      if (prev == null || m.createdAt.compareTo(prev.createdAt) >= 0) {
        latestByPeer[peer] = m;
      }
      if (m.toUserId == meId && !m.read) {
        unreadByPeer[peer] = (unreadByPeer[peer] ?? 0) + 1;
      }
    }
    final previews = latestByPeer.entries.map((e) {
      final m = e.value;
      final peerName = m.fromUserId == meId
          ? (m.toUserName.isNotEmpty
              ? m.toUserName
              : resolvePeerName(e.key))
          : (m.fromUserName.isNotEmpty
              ? m.fromUserName
              : resolvePeerName(e.key));
      return ConversationPreview(
        userId: e.key,
        name: peerName,
        avatar: resolvePeerAvatar(e.key),
        lastMessage: m.text,
        updatedAt: m.createdAt,
        unreadCount: unreadByPeer[e.key] ?? 0,
      );
    }).toList();
    previews.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return previews;
  }

  static int unreadCountFor(String meId) {
    return listAll()
        .where((m) => m.toUserId == meId && !m.read)
        .length;
  }

  static Future<void> upsert(DirectMessage msg) async {
    final rows = [...listAll()];
    final idx = rows.indexWhere((m) => m.id == msg.id);
    if (idx >= 0) {
      rows[idx] = msg;
    } else {
      rows.add(msg);
    }
    await _save(rows);
    try {
      await CloudStore.upsertDocs(CloudStore.directMessages, [msg.toJson()]);
    } catch (_) {}
  }

  static Future<DirectMessage> send({
    required HubsomUser from,
    required String toUserId,
    required String text,
    String? toUserName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw StateError('Write a message first');
    if (toUserId.isEmpty) throw StateError('Pick someone to message');
    if (toUserId == from.id) throw StateError('You cannot message yourself');

    final msg = DirectMessage(
      id: 'dm-${_uuid.v4().substring(0, 10)}',
      fromUserId: from.id,
      toUserId: toUserId,
      text: trimmed,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      fromUserName: from.name,
      toUserName: resolvePeerName(toUserId, fallback: toUserName),
      read: false,
    );
    await upsert(msg);
    return msg;
  }

  static Future<void> markThreadRead({
    required String meId,
    required String peerId,
  }) async {
    final rows = [...listAll()];
    var changed = false;
    final next = <DirectMessage>[];
    for (final m in rows) {
      final incoming = m.fromUserId == peerId && m.toUserId == meId;
      if (incoming && !m.read) {
        next.add(m.copyWith(read: true));
        changed = true;
      } else {
        next.add(m);
      }
    }
    if (!changed) return;
    await _save(next);
    try {
      final updated = next
          .where((m) => m.fromUserId == peerId && m.toUserId == meId && m.read)
          .map((m) => m.toJson())
          .toList();
      if (updated.isNotEmpty) {
        await CloudStore.upsertDocs(CloudStore.directMessages, updated);
      }
    } catch (_) {}
  }
}
