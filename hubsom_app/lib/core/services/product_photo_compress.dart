import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class _CompressArgs {
  const _CompressArgs(this.bytes, this.maxSide, this.quality);
  final Uint8List bytes;
  final int maxSide;
  final int quality;
}

Uint8List _compressSync(_CompressArgs args) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) return args.bytes;

  var image = decoded;
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > args.maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: args.maxSide)
        : img.copyResize(image, height: args.maxSide);
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: args.quality));
}

/// Shrink phone-camera photos so product publish fits browser storage.
///
/// Without this, typical 2–8MB camera JPEGs were rejected by the 1.5MB check
/// and sellers could not finish product creation before Go live.
Future<Uint8List> compressProductPhoto(
  Uint8List bytes, {
  int maxSide = 1280,
  int quality = 72,
}) {
  if (bytes.isEmpty) return Future.value(bytes);
  return compute(_compressSync, _CompressArgs(bytes, maxSide, quality));
}
