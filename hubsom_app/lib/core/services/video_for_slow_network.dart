import 'dart:typed_data';

import 'mp4_faststart.dart';
import 'product_demo_video.dart';
import 'video_recompress.dart';

/// Prepare an uploaded clip so the first frame can start on a slow network.
///
/// 1. Re-encode at a low bitrate when the browser can (web only).
/// 2. Move the MP4 `moov` atom to the front so streaming does not wait
///    for the last byte of the file.
Future<ProductDemoVideo> prepareShopVideoForSlowNetwork({
  required Uint8List bytes,
  required String mimeType,
  double durationSeconds = 0,
  String name = 'clip.mp4',
}) async {
  var outBytes = bytes;
  var outMime = mimeType.isEmpty ? 'video/mp4' : mimeType;
  var outDuration = durationSeconds;

  final compressed = await recompressShopVideoForSlowNetwork(
    bytes: bytes,
    mimeType: outMime,
  );
  if (compressed != null && compressed.bytes.isNotEmpty) {
    outBytes = compressed.bytes;
    outMime = compressed.mimeType;
    if (compressed.durationSeconds > 0) {
      outDuration = compressed.durationSeconds;
    }
  }

  if (outMime.contains('mp4') || outMime.contains('quicktime')) {
    outBytes = ensureMp4FastStart(outBytes);
  }

  return ProductDemoVideo(
    bytes: outBytes,
    mimeType: outMime,
    durationSeconds: outDuration,
    name: name,
  );
}
