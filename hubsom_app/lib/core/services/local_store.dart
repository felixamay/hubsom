import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/cart.dart';

/// Durable device storage. SharedPreferences (localStorage on web) is the
/// source of truth so accounts survive refresh. Hive is migrated once.
class LocalStore {
  LocalStore._();

  static const _prefix = 'hubsom_';
  static const _boxName = 'hubsom';

  static late SharedPreferences _prefs;
  static Box? _box;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      _box = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
      await _migrateHiveOnce();
    } catch (_) {
      _box = null;
    }
  }

  static Future<void> _migrateHiveOnce() async {
    final box = _box;
    if (box == null) return;
    const migratedKey = '${_prefix}hive_migrated_v1';
    if (_prefs.getBool(migratedKey) == true) return;

    for (final key in box.keys) {
      if (key is! String) continue;
      final dest = '$_prefix$key';
      if (_prefs.containsKey(dest)) continue;
      final value = box.get(key);
      if (value is String) {
        await _prefs.setString(dest, value);
      } else if (value is bool) {
        await _prefs.setBool(dest, value);
      } else if (value is int) {
        await _prefs.setInt(dest, value);
      }
    }
    await _prefs.setBool(migratedKey, true);
  }

  static String? getString(String key) => _prefs.getString('$_prefix$key');

  static Future<void> setString(String key, String? value) async {
    final dest = '$_prefix$key';
    if (value == null || value.isEmpty) {
      await _prefs.remove(dest);
    } else {
      await _prefs.setString(dest, value);
    }
    try {
      if (_box != null) {
        if (value == null || value.isEmpty) {
          await _box!.delete(key);
        } else {
          await _box!.put(key, value);
        }
      }
    } catch (_) {}
  }

  static bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool('$_prefix$key') ?? fallback;

  static Future<void> setBool(String key, bool value) async {
    await _prefs.setBool('$_prefix$key', value);
    try {
      await _box?.put(key, value);
    } catch (_) {}
  }

  static Future<void> remove(String key) async {
    await _prefs.remove('$_prefix$key');
    try {
      await _box?.delete(key);
    } catch (_) {}
  }

  static String? get sessionToken => getString('sessionToken');
  static String? get userJson => getString('userJson');

  static Future<void> setSessionToken(String? value) =>
      setString('sessionToken', value);

  static Future<void> setUserJson(String? value) => setString('userJson', value);

  /// Local credential vault: email → { salt, hash, userJson }
  static Map<String, dynamic> loadCredentialVault() {
    final raw = getString('credentialVault');
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveCredentialVault(Map<String, dynamic> vault) async {
    await setString('credentialVault', jsonEncode(vault));
  }

  static List<CartItem> loadCart() {
    final raw = getString('cart');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCart(List<CartItem> items) async {
    await setString(
      'cart',
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> cacheJson(String key, Object data) async {
    await setString('cache_$key', jsonEncode(data));
  }

  static dynamic readCache(String key) {
    final raw = getString('cache_$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Clears the signed-in session only. Credential vault stays so login works.
  static Future<void> clearSession() async {
    await setSessionToken(null);
    await setUserJson(null);
  }
}
