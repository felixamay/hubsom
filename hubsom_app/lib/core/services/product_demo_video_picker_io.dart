import 'package:image_picker/image_picker.dart';

import 'product_demo_video.dart';
import 'shop_video_limits.dart';

/// Mobile/desktop gallery picker for a short product demo video.
Future<ProductDemoVideo?> pickProductDemoVideo({int maxSeconds = 15}) async {
  final picker = ImagePicker();
  final file = await picker.pickVideo(
    source: ImageSource.gallery,
    maxDuration: Duration(seconds: maxSeconds),
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) return null;
  if (bytes.lengthInBytes > ShopVideoLimits.maxBytes) {
    throw StateError(ShopVideoLimits.sizeError(maxSeconds));
  }

  final mime = file.mimeType ?? 'video/mp4';
  if (!isWidelyPlayableShopVideo(bytes: bytes, mimeType: mime)) {
    throw StateError(
      'Use an MP4 so the clip can play on iPhone and Android.',
    );
  }

  // image_picker enforces maxDuration on supported platforms; treat as ≤ max.
  return ProductDemoVideo(
    bytes: bytes,
    mimeType: shopVideoPlaybackMime(bytes: bytes, mimeType: mime),
    durationSeconds: maxSeconds.toDouble(),
    name: file.name,
  );
}
