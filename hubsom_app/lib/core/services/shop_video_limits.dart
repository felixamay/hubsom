import 'dart:typed_data';

import 'mp4_faststart.dart';

/// Shop-video upload limits and a check so clips play on iPhone and Android.
class ShopVideoLimits {
  ShopVideoLimits._();

  static const maxSeconds = 120;
  static const maxBytes = 40 * 1024 * 1024;

  static String get pickLabel => 'Pick video (≤2 min, MP4)';

  static String sizeError(int maxSeconds) =>
      'Video is too large. Use an MP4 under 40MB (max $maxSeconds seconds).';

  static String durationError(int maxSeconds, double actual) =>
      'Video must be $maxSeconds seconds or shorter (yours is ${actual.toStringAsFixed(1)}s).';
}

/// True when the clip is MP4/MOV (H.264/HEVC). WebM does not play on iPhone.
bool isWidelyPlayableShopVideo({
  required Uint8List bytes,
  required String mimeType,
}) {
  if (bytes.isEmpty) return false;
  if (_looksLikeWebm(bytes)) return false;
  final mime = mimeType.toLowerCase();
  if (mime.contains('webm') ||
      mime.contains('ogg') ||
      mime.contains('mkv') ||
      mime.contains('x-matroska')) {
    return false;
  }
  if (looksLikeMp4(bytes)) return true;
  return mime.contains('mp4') ||
      mime.contains('quicktime') ||
      mime.contains('x-m4v');
}

String shopVideoPlaybackMime({
  required Uint8List bytes,
  required String mimeType,
}) {
  if (looksLikeMp4(bytes)) return 'video/mp4';
  final mime = mimeType.trim();
  return mime.isEmpty ? 'video/mp4' : mime;
}

bool _looksLikeWebm(Uint8List bytes) {
  return bytes.length >= 4 &&
      bytes[0] == 0x1a &&
      bytes[1] == 0x45 &&
      bytes[2] == 0xdf &&
      bytes[3] == 0xa3;
}
