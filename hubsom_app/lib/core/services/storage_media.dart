import 'dart:convert';

import 'local_blob_store.dart';
import 'local_store.dart';

/// Keep browser localStorage small — camera/data-URL blobs go to Hive.
abstract final class StorageMedia {
  static const _prefsKeysWithMedia = <String>[
    'localProducts',
    'localSellers',
    'localStreams',
    'localTimelinePosts',
    'localSellerFollowers',
    'localChat',
    'localProductComments',
    'localProductReviews',
    'localShopVideos',
    'userJson',
    'credentialVault',
    'cart',
  ];

  static bool isInlineData(String? value) {
    final v = value?.trim() ?? '';
    return v.startsWith('data:') && v.contains('base64,');
  }

  /// HTTP(S), blob refs, and short paths stay. Raw data-URLs are not persisted
  /// on stream covers — they already live on the product.
  static String persistable(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '';
    if (LocalBlobStore.isRef(v)) return v;
    if (isInlineData(v)) return '';
    if (v.length > 2048) return '';
    return v;
  }

  static Future<dynamic> externalizeTree(dynamic node) async {
    if (node is String) {
      if (LocalBlobStore.isRef(node) || !isInlineData(node)) return node;
      return LocalBlobStore.putDataUrl(node);
    }
    if (node is List) {
      final out = <dynamic>[];
      for (final e in node) {
        out.add(await externalizeTree(e));
      }
      return out;
    }
    if (node is Map) {
      final out = <String, dynamic>{};
      for (final e in node.entries) {
        out['${e.key}'] = await externalizeTree(e.value);
      }
      return out;
    }
    return node;
  }

  /// Move existing data-URL photos out of SharedPreferences into Hive.
  static Future<int> migratePrefsBlobs() async {
    await LocalBlobStore.init();
    var n = 0;
    for (final key in _prefsKeysWithMedia) {
      final raw = LocalStore.getString(key);
      if (raw == null || raw.isEmpty || !raw.contains('data:')) continue;
      try {
        final trimmed = raw.trim();
        final decoded = trimmed.startsWith('{') || trimmed.startsWith('[')
            ? jsonDecode(raw)
            : raw;
        final next = await externalizeTree(decoded);
        final encoded = next is String ? next : jsonEncode(next);
        if (encoded.length >= raw.length) continue;
        await LocalStore.setString(key, encoded, reclaim: false);
        n++;
      } catch (_) {}
    }
    return n;
  }
}
