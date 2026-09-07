import '../../models/shop_video.dart';
import 'local_blob_store.dart';

/// Largest inline JPEG we put in a Firestore shop-video doc (1 MiB doc cap).
const int shopVideoInlineThumbMaxChars = 450 * 1024;

/// A thumbnail every device can load: https, or a small `data:` JPEG.
///
/// There is no Storage bucket on this project, so the still travels inside
/// the Firestore doc. Device-only `hubsom-blob://` refs are resolved to their
/// data URL first.
String? portableShopVideoThumb(String? raw) {
  final v = raw?.trim() ?? '';
  if (v.isEmpty || v == 'null') return null;
  if (v.startsWith('http://') || v.startsWith('https://')) return v;
  final resolved = LocalBlobStore.isRef(v) ? LocalBlobStore.resolve(v) : v;
  final data = resolved?.trim() ?? '';
  if (!data.startsWith('data:image')) return null;
  if (data.length > shopVideoInlineThumbMaxChars) return null;
  return data;
}

/// Firestore payload for [video] with a thumbnail other phones can show.
Map<String, dynamic> shopVideoCloudJson(ShopVideo video) {
  return video.toCloudJson(thumbnail: portableShopVideoThumb(video.thumbnailUrl));
}
