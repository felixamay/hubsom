import 'dart:convert';

import 'local_store.dart';

/// Shop-video ids this device has deleted.
///
/// Publish writes metadata in the background. Without a tombstone, that write
/// (or a later cloud hydrate) can put a deleted clip back on Home / Timeline.
abstract final class ShopVideoTombstones {
  static const key = 'localDeletedShopVideos';
  static const _maxIds = 400;

  static Set<String> ids() {
    final raw = LocalStore.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw);
      if (list is! List) return {};
      return {
        for (final e in list)
          if ('$e'.trim().isNotEmpty) '$e'.trim(),
      };
    } catch (_) {
      return {};
    }
  }

  static bool contains(String videoId) {
    final id = videoId.trim();
    return id.isNotEmpty && ids().contains(id);
  }

  static Future<void> remember(String videoId) async {
    final id = videoId.trim();
    if (id.isEmpty) return;
    final next = [id, ...ids().where((e) => e != id)];
    if (next.length > _maxIds) {
      next.removeRange(_maxIds, next.length);
    }
    await LocalStore.setString(key, jsonEncode(next));
  }

  static bool isDeletedVideoPost(Map<String, dynamic> row) {
    final videoId = '${row['videoId'] ?? ''}'.trim();
    return videoId.isNotEmpty && contains(videoId);
  }
}
