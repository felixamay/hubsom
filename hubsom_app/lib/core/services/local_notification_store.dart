import 'dart:convert';

import '../../models/app_notification.dart';
import '../../models/stream.dart';
import '../../models/user.dart';
import 'cloud_store.dart';
import 'local_commerce_store.dart';
import 'local_store.dart';
import 'notification_service.dart';

/// In-app alerts (device + Firestore) — e.g. a followed store going live.
class LocalNotificationStore {
  LocalNotificationStore._();

  static const key = 'localNotifications';

  static List<HubsomNotification> listAll() {
    final raw = LocalStore.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = List<dynamic>.from(jsonDecode(raw) as List);
      return list
          .map(
            (e) => HubsomNotification.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _save(List<HubsomNotification> rows) async {
    await LocalStore.setString(
      key,
      jsonEncode(rows.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> mergeCloud() async {
    try {
      final remote = await CloudStore.listDocs(CloudStore.notifications);
      if (remote.isEmpty) return;
      final byId = <String, HubsomNotification>{
        for (final n in listAll()) n.id: n,
      };
      for (final row in remote) {
        try {
          final n = HubsomNotification.fromJson(row);
          byId[n.id] = n;
        } catch (_) {}
      }
      await _save(byId.values.toList());
    } catch (_) {}
  }

  static List<HubsomNotification> forUser(String userId) {
    final list = listAll().where((n) => n.userId == userId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static int unreadCountFor(String userId) {
    return forUser(userId).where((n) => !n.read).length;
  }

  static Future<void> upsert(HubsomNotification note) async {
    final rows = [...listAll()];
    final idx = rows.indexWhere((n) => n.id == note.id);
    if (idx >= 0) {
      rows[idx] = note;
    } else {
      rows.add(note);
    }
    await _save(rows);
    try {
      await CloudStore.upsertDocs(CloudStore.notifications, [note.toJson()]);
    } catch (_) {}
  }

  static Future<void> markRead(String id) async {
    final rows = listAll();
    final idx = rows.indexWhere((n) => n.id == id);
    if (idx < 0 || rows[idx].read) return;
    await upsert(rows[idx].copyWith(read: true));
  }

  /// User ids that follow [sellerId] on the live follow graph.
  static Set<String> followerUserIds(String sellerId) {
    final ids = <String>{};
    for (final row in LocalCommerceStore.listFollowers(sellerId)) {
      final id = '${row['userId']}'.trim();
      if (id.isNotEmpty) ids.add(id);
    }
    return ids;
  }

  /// Alert every follower that [stream] just started.
  static Future<List<HubsomNotification>> notifySellerWentLive(
    LiveStream stream, {
    NotificationService? banners,
  }) async {
    if (!stream.isLive) return const [];
    final seller = LocalCommerceStore.getSeller(stream.sellerId);
    final storeName = (seller?.name.trim().isNotEmpty == true)
        ? seller!.name.trim()
        : (stream.hosts.isNotEmpty && stream.hosts.first.name.trim().isNotEmpty)
            ? stream.hosts.first.name.trim()
            : 'A store you follow';
    final skip = <String>{
      if (seller?.ownerUserId != null && seller!.ownerUserId!.isNotEmpty)
        seller.ownerUserId!,
      for (final h in stream.hosts) h.id,
    };
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final title = '$storeName is live';
    final body = stream.title.trim().isEmpty
        ? 'Watch the show now on Hubsom.'
        : stream.title.trim();
    final route = '/live/${stream.id}';

    final out = <HubsomNotification>[];
    for (final userId in followerUserIds(stream.sellerId)) {
      if (skip.contains(userId)) continue;
      final note = HubsomNotification(
        id: 'n-live-${stream.id}-$userId',
        userId: userId,
        type: 'seller_live',
        title: title,
        body: body,
        createdAt: createdAt,
        route: route,
        streamId: stream.id,
        sellerId: stream.sellerId,
      );
      await upsert(note);
      out.add(note);
    }

    final session = _sessionUser();
    if (session != null && banners != null) {
      final mine = out.where((n) => n.userId == session.id);
      for (final note in mine) {
        await banners.showLocal(title: note.title, body: note.body);
      }
    }
    return out;
  }

  static HubsomUser? _sessionUser() {
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
}
