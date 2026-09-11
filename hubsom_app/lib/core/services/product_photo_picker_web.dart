import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'product_photo.dart';

/// Browser file picker — no image_picker plugin channel (avoids MissingPluginException).
Future<List<ProductPhoto>> pickProductPhotos({required int remaining}) async {
  if (remaining <= 0) return const [];

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/jpeg,image/png,image/webp,image/gif,image/*'
    ..multiple = remaining > 1;
  input.style.display = 'none';
  web.document.body?.append(input);

  final completer = Completer<List<ProductPhoto>>();

  void finish(List<ProductPhoto> photos) {
    input.remove();
    if (!completer.isCompleted) completer.complete(photos);
  }

  input.addEventListener(
    'change',
    (web.Event _) {
      () async {
        try {
          final files = input.files;
          if (files == null || files.length == 0) {
            finish(const []);
            return;
          }
          final photos = <ProductPhoto>[];
          final count = files.length < remaining ? files.length : remaining;
          for (var i = 0; i < count; i++) {
            final file = files.item(i);
            if (file == null) continue;
            final type = file.type.toLowerCase();
            if (type.isNotEmpty && !type.startsWith('image/')) continue;
            final buffer = await file.arrayBuffer().toDart;
            final bytes = buffer.toDart.asUint8List();
            if (bytes.isEmpty) continue;
            photos.add(
              ProductPhoto(
                bytes: bytes,
                mimeType: type.isEmpty ? 'image/jpeg' : type,
                name: file.name,
              ),
            );
          }
          finish(photos);
        } catch (_) {
          finish(const []);
        }
      }();
    }.toJS,
  );

  input.addEventListener(
    'cancel',
    (web.Event _) {
      finish(const []);
    }.toJS,
  );

  Future<void>.delayed(const Duration(minutes: 2), () {
    if (!completer.isCompleted) finish(const []);
  });

  input.click();
  return completer.future;
}
