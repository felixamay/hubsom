import 'dart:typed_data';

import 'product_demo_video.dart';

/// Native/tests: no MediaRecorder. Fast-start remux is enough.
Future<ProductDemoVideo?> recompressShopVideoForSlowNetwork({
  required Uint8List bytes,
  required String mimeType,
}) async =>
    null;
