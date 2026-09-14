import 'dart:typed_data';

/// Native / tests: no HTML video element to grab a JPEG still.
Future<Uint8List?> captureShopVideoFrame({
  required Uint8List bytes,
  required String mimeType,
}) async =>
    null;

/// Native / tests: no canvas grab from a remote clip URL.
Future<Uint8List?> captureShopVideoFrameFromUrl(String url) async => null;
