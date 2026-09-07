import 'dart:typed_data';

import 'product_demo_video.dart';
import 'shop_video_limits.dart';

/// Prepare an uploaded clip so playback can start after the first kilobytes.
///
/// Only remux the MP4 `moov` atom. A full browser MediaRecorder pass used to
/// sit on "Publishing video…" for the whole clip — or forever if `play()`
/// never resolved.
Future<ProductDemoVideo> prepareShopVideoForSlowNetwork({
  required Uint8List bytes,
  required String mimeType,
  double durationSeconds = 0,
  String name = 'clip.mp4',
}) async {
  if (!isWidelyPlayableShopVideo(bytes: bytes, mimeType: mimeType)) {
    throw StateError(
      'Use an MP4 so the clip can play on iPhone and Android.',
    );
  }

  // Do not remux large clips during Publish — that blocked uploads on slow phones.
  // Downloaded copies still get faststart in [CloudVideoMedia.ensureLocalBytes].
  return ProductDemoVideo(
    bytes: bytes,
    mimeType: shopVideoPlaybackMime(bytes: bytes, mimeType: mimeType),
    durationSeconds: durationSeconds,
    name: name,
  );
}
