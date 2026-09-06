import '../../models/shop_video.dart';
import '../config/firebase_options.dart';
import 'local_blob_store.dart';

/// Resolve a still image URL for shop-video cards (Home, Timeline, feed).
abstract final class ShopVideoPosterUrl {
  static String get _storageBucket =>
      DefaultFirebaseOptions.web.storageBucket ?? '';

  /// Public Storage URL for the standard `{videoId}_thumb.jpg` still.
  static String? storageThumbUrl(String videoId) {
    if (videoId.isEmpty || _storageBucket.isEmpty) return null;
    final objectPath =
        Uri.encodeComponent('shopVideos/${videoId}_thumb.jpg');
    return 'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o/$objectPath?alt=media';
  }

  /// Prefer a local blob / data URL, else the uploaded Storage still.
  static String? resolve(ShopVideo video) {
    final raw = video.thumbnailUrl?.trim() ?? '';
    if (raw.isNotEmpty) {
      final resolved = LocalBlobStore.resolve(raw) ?? raw;
      if (resolved.isNotEmpty && !LocalBlobStore.isRef(resolved)) {
        return resolved;
      }
    }
    if (video.hasPublishedMedia) {
      return storageThumbUrl(video.id);
    }
    return null;
  }
}
