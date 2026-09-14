import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../models/user.dart';
import '../services/local_store.dart';
import 'afia_session_stub.dart'
    if (dart.library.js_interop) 'afia_session_web.dart';

/// Hubsom admin portal at `https://hubsom.com/afia`.
///
/// Not linked from buyer/seller menus. The door is a standalone login
/// (owner email + portal password). A Hubsom storefront session is not
/// required — visiting `/afia` always shows a real admin webpage.
abstract final class AfiaAccess {
  static const path = '/afia';
  static const appPath = '/afia';
  static const legacyAdminPath = '/hubsom-admin';
  static const ownerEmail = 'felixames0808@gmail.com';
  static const _salt = 'afia-portal';
  static const _unlockKey = 'afiaUnlockedEmail';

  /// sha256 of `afia-portal::Newmoney@2025::hubsom`
  static const _passwordHash =
      'ac668d772d82fb28c85601fb52fef2d4cf127147fced8701ac69fa9c70f78601';

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static bool isOwnerEmail(String? email) =>
      normalizeEmail(email ?? '') == ownerEmail;

  static bool isOwner(HubsomUser? user) => isOwnerEmail(user?.email);

  static String _normalizedPath(String location) {
    var value = location.split('?').first.trim();
    if (value.length > 1 && value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  /// True for `/afia`, `/Afia`, `/hubsom-admin`, etc.
  static bool matchesPath(String location) {
    final normalized = _normalizedPath(location).toLowerCase();
    return normalized == path || normalized == legacyAdminPath;
  }

  /// Canonicalize to `/afia`. Old `/hubsom-admin` and `/Afia` redirect here.
  static String? canonicalRedirect(String location) {
    final normalized = _normalizedPath(location).toLowerCase();
    final raw = location.split('?').first.trim();
    if (normalized == path || normalized == legacyAdminPath) {
      return raw == path ? null : path;
    }
    return null;
  }

  static bool checkPassword(String password) {
    final hash =
        sha256.convert(utf8.encode('$_salt::${password.trim()}::hubsom')).toString();
    return hash == _passwordHash;
  }

  static bool isUnlocked([HubsomUser? user]) {
    return LocalStore.getString(_unlockKey) == ownerEmail;
  }

  static Future<bool> unlock({
    HubsomUser? user,
    String? email,
    required String password,
  }) async {
    final resolved = email ?? user?.email;
    if (!isOwnerEmail(resolved) || !checkPassword(password)) return false;
    await LocalStore.setString(_unlockKey, ownerEmail);
    return true;
  }

  static Future<void> lock() => LocalStore.setString(_unlockKey, null);

  /// End the Afia session. On web this reloads `/afia` so the login door shows.
  static Future<void> logout() async {
    await lock();
    leaveAfiaSession();
  }
}
