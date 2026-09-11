import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../models/message.dart';
import '../../models/user.dart';
import '../auth/afia_access.dart';
import '../support/support_chat.dart';
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

  static Set<String> _selfIds(String userId) {
    final ids = <String>{userId};
    if (userId == SupportChat.peerId) return ids;
    final raw = LocalStore.userJson;
    if (raw == null || raw.isEmpty) return ids;
    try {
      final user = HubsomUser.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (user.id == userId && SupportChat.receivesInbox(user)) {
        ids.add(SupportChat.peerId);
      }
    } catch (_) {}
    if (AfiaAccess.isOwnerEmail(userId)) {
      ids.add(SupportChat.peerId);
    }
    return ids;
  }

  static List<DirectMessage> forUser(String userId) {
    final self = _selfIds(userId);
    final list = listAll()
        .where((m) => self.contains(m.fromUserId) || self.contains(m.toUserId))
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  static List<DirectMessage> thread(String meId, String peerId) {
    final self = _selfIds(meId);
    final list = listAll()
        .where(
          (m) =>
              (self.contains(m.fromUserId) && m.toUserId == peerId) ||
              (m.fromUserId == peerId && self.contains(m.toUserId)),
        )
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  static String resolvePeerName(String peerId, {String? fallback}) {
    if (SupportChat.isSupportPeer(peerId)) return SupportChat.displayName;
    if (fallback != null && fallback.trim().isNotEmpty) return fallback.trim();
    for (final s in LocalCommerceStore.listSellers()) {
      if (s.id == peerId || s.ownerUserId == peerId) return s.name;
    }
    // Followers / following records often have the display name.
    for (final s in LocalCommerceStore.listSellers()) {
      for (final f in LocalCommerceStore.listFollowers(s.id)) {
        if ('${f['userId']}' == peerId) {
          final n = '${f['name'] ?? ''}'.trim();
          if (n.isNotEmpty) return n;
        }
      }
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
    final self = _selfIds(meId);
    final mine = forUser(meId);
    final latestByPeer = <String, DirectMessage>{};
    final unreadByPeer = <String, int>{};
    for (final m in mine) {
      final peer = self.contains(m.fromUserId) ? m.toUserId : m.fromUserId;
      if (peer.isEmpty || self.contains(peer)) continue;
      final prev = latestByPeer[peer];
      if (prev == null || m.createdAt.compareTo(prev.createdAt) >= 0) {
        latestByPeer[peer] = m;
      }
      if (self.contains(m.toUserId) && !m.read) {
        unreadByPeer[peer] = (unreadByPeer[peer] ?? 0) + 1;
      }
    }
    final previews = latestByPeer.entries.map((e) {
      final m = e.value;
      final mineMsg = self.contains(m.fromUserId);
      final peerName = mineMsg
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
    final self = _selfIds(meId);
    return listAll()
        .where((m) => self.contains(m.toUserId) && !m.read)
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
    final toName = SupportChat.isSupportPeer(toUserId)
        ? SupportChat.displayName
        : resolvePeerName(toUserId, fallback: toUserName);

    final msg = DirectMessage(
      id: 'dm-${_uuid.v4().substring(0, 10)}',
      fromUserId: from.id,
      toUserId: toUserId,
      text: trimmed,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      fromUserName: SupportChat.isSupportPeer(from.id)
          ? SupportChat.displayName
          : from.name,
      toUserName: toName,
      read: false,
    );
    await upsert(msg);
    return msg;
  }

  static Future<void> markThreadRead({
    required String meId,
    required String peerId,
  }) async {
    final self = _selfIds(meId);
    final rows = [...listAll()];
    var changed = false;
    final next = <DirectMessage>[];
    for (final m in rows) {
      final incoming = m.fromUserId == peerId && self.contains(m.toUserId);
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
          .where((m) => m.fromUserId == peerId && self.contains(m.toUserId) && m.read)
          .map((m) => m.toJson())
          .toList();
      if (updated.isNotEmpty) {
        await CloudStore.upsertDocs(CloudStore.directMessages, updated);
      }
    } catch (_) {}
  }
}
