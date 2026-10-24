import 'dart:typed_data';

import 'product_demo_blob_url_io.dart'
    if (dart.library.js_interop) 'product_demo_blob_url_web.dart' as impl;

/// Creates a playable URL for [bytes] (blob on web, temp file elsewhere).
Future<String> createDemoVideoObjectUrl({
  required Uint8List bytes,
  required String mimeType,
}) =>
    impl.createDemoVideoObjectUrl(bytes: bytes, mimeType: mimeType);

Future<void> revokeDemoVideoObjectUrl(String url) =>
    impl.revokeDemoVideoObjectUrl(url);
