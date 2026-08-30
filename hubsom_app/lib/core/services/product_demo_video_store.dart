import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';

/// Stores product demo video bytes outside product JSON (avoids localStorage quota).
class ProductDemoVideoStore {
  ProductDemoVideoStore._();

  static const _boxName = 'hubsom_product_videos';
  static Box? _box;

  static Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox(_boxName);
  }

  static String _bytesKey(String productId) => 'bytes_$productId';
  static String _mimeKey(String productId) => 'mime_$productId';

  static bool hasVideo(String productId) {
    final box = _box;
    if (box == null) return false;
    return box.containsKey(_bytesKey(productId));
  }

  static Future<void> save({
    required String productId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    await init();
    await _box!.put(_bytesKey(productId), bytes);
    await _box!.put(_mimeKey(productId), mimeType);
  }

  static Future<({Uint8List bytes, String mimeType})?> load(String productId) async {
    await init();
    final raw = _box!.get(_bytesKey(productId));
    if (raw is! Uint8List || raw.isEmpty) return null;
    final mime = '${_box!.get(_mimeKey(productId)) ?? 'video/mp4'}';
    return (bytes: raw, mimeType: mime);
  }

  static Future<void> remove(String productId) async {
    await init();
    await _box!.delete(_bytesKey(productId));
    await _box!.delete(_mimeKey(productId));
  }
}
