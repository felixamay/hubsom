import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../models/user.dart';
import '../services/local_store.dart';

/// Hubsom admin portal at `/Afia`. Not linked from buyer/seller menus.
///
/// The door is a standalone login (owner email + portal password). A Hubsom
/// storefront session is not required — visiting the URL always shows a real
/// admin webpage.
abstract final class AfiaAccess {
  static const path = '/Afia';
  static const appPath = '/hubsom-admin';
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

  /// True for `/Afia`, `/afia`, `/AFIA/`, etc.
  static bool matchesPath(String location) {
    final normalized = _normalizedPath(location).toLowerCase();
    return normalized == '/afia' || normalized == '/hubsom-admin';
  }

  /// Canonicalize Afia / admin casing and trailing slashes.
  static String? canonicalRedirect(String location) {
    final normalized = _normalizedPath(location).toLowerCase();
    final raw = location.split('?').first.trim();
    if (normalized == '/afia') {
      return raw == '/Afia' ? null : path;
    }
    if (normalized == '/hubsom-admin') {
      return raw == appPath ? null : appPath;
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
}
