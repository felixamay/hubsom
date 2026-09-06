import 'dart:typed_data';

import 'mp4_faststart.dart';
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

  var outBytes = bytes;
  if (looksLikeMp4(outBytes) ||
      mimeType.contains('mp4') ||
      mimeType.contains('quicktime')) {
    outBytes = ensureMp4FastStart(outBytes);
  }

  return ProductDemoVideo(
    bytes: outBytes,
    mimeType: shopVideoPlaybackMime(bytes: outBytes, mimeType: mimeType),
    durationSeconds: durationSeconds,
    name: name,
  );
}
