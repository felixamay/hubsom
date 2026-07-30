import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../models/cart.dart';

/// Offline cache + session helpers (Hive).
class LocalStore {
  LocalStore._();

  static const _boxName = 'hubsom';
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static String? get sessionToken => _box.get('sessionToken') as String?;
  static set sessionToken(String? value) {
    if (value == null) {
      _box.delete('sessionToken');
    } else {
      _box.put('sessionToken', value);
    }
  }

  static String? get userJson => _box.get('userJson') as String?;
  static set userJson(String? value) {
    if (value == null) {
      _box.delete('userJson');
    } else {
      _box.put('userJson', value);
    }
  }

  static List<CartItem> loadCart() {
    final raw = _box.get('cart') as String?;
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> saveCart(List<CartItem> items) async {
    await _box.put('cart', jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static Future<void> cacheJson(String key, Object data) async {
    await _box.put('cache_$key', jsonEncode(data));
  }

  static dynamic readCache(String key) {
    final raw = _box.get('cache_$key') as String?;
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  static Future<void> clearSession() async {
    await _box.delete('sessionToken');
    await _box.delete('userJson');
  }
}
