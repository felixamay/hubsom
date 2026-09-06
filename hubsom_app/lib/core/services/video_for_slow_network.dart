import 'dart:typed_data';

import 'mp4_faststart.dart';
import 'product_demo_video.dart';

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
  var outBytes = bytes;
  final outMime = mimeType.isEmpty ? 'video/mp4' : mimeType;

  if (outMime.contains('mp4') || outMime.contains('quicktime')) {
    outBytes = ensureMp4FastStart(outBytes);
  }

  return ProductDemoVideo(
    bytes: outBytes,
    mimeType: outMime,
    durationSeconds: durationSeconds,
    name: name,
  );
}
