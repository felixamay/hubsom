import '../../models/shop_video.dart';
import 'cloud_media.dart';
import 'cloud_storage_status.dart';
import 'local_blob_store.dart';

/// Resolve a still image URL for shop-video cards (Home, Timeline, feed).
abstract final class ShopVideoPosterUrl {
  static String get _storageBucket => CloudStorageStatus.bucket;

  /// Public Storage URL for the standard `{videoId}_thumb.jpg` still.
  static String? storageThumbUrl(String videoId) {
    if (videoId.isEmpty || _storageBucket.isEmpty) return null;
    final objectPath =
        Uri.encodeComponent('shopVideos/${videoId}_thumb.jpg');
    return 'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o/$objectPath?alt=media';
  }

  /// Prefer a local blob / data URL / https still. Only guess the Storage
  /// path when the clip streams from Storage and the project actually has a
  /// bucket — otherwise every card would fire a doomed 404 image request.
  static String? resolve(ShopVideo video) {
    final raw = video.thumbnailUrl?.trim() ?? '';
    if (raw.isNotEmpty && raw != 'null') {
      final resolved = LocalBlobStore.resolve(raw) ?? raw;
      if (resolved.isNotEmpty && !LocalBlobStore.isRef(resolved)) {
        return resolved;
      }
    }
    if (video.hasRemoteVideo && CloudMedia.storageKnownAvailable) {
      return storageThumbUrl(video.id);
    }
    return null;
  }
}
