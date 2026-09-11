import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Image bytes live in Hive (IndexedDB on web) instead of localStorage.
class LocalBlobStore {
  LocalBlobStore._();

  static const scheme = 'hubsom-blob://';
  static const _boxName = 'hubsom_media_blobs';
  static Box? _box;

  static Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox(_boxName);
  }

  static bool isRef(String? value) =>
      (value ?? '').trim().startsWith(scheme);

  static String _idFor(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    final payload = comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl;
    return sha1.convert(utf8.encode(payload)).toString();
  }

  static Future<String> putDataUrl(String dataUrl) async {
    await init();
    final raw = dataUrl.trim();
    final id = _idFor(raw);
    if (!(_box!.containsKey(id))) {
      await _box!.put(id, raw);
    }
    return '$scheme$id';
  }

  static String? resolve(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return v;
    if (!isRef(v)) return v;
    final box = _box;
    if (box == null || !box.isOpen) return null;
    final stored = box.get(v.substring(scheme.length));
    return stored is String && stored.isNotEmpty ? stored : null;
  }
}
