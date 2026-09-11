import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String> createDemoVideoObjectUrl({
  required Uint8List bytes,
  required String mimeType,
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  return web.URL.createObjectURL(blob);
}

Future<void> revokeDemoVideoObjectUrl(String url) async {
  if (url.startsWith('blob:')) {
    web.URL.revokeObjectURL(url);
  }
}
