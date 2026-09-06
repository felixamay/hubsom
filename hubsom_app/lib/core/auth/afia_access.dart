import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../models/user.dart';
import '../services/local_store.dart';

/// Hidden Hubsom admin door at `/Afia`. Not linked from any account menu.
abstract final class AfiaAccess {
  static const path = '/Afia';
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

  static bool checkPassword(String password) {
    final hash = sha256.convert(utf8.encode('$_salt::$password::hubsom')).toString();
    return hash == _passwordHash;
  }

  static bool isUnlocked(HubsomUser? user) {
    if (!isOwner(user)) return false;
    return LocalStore.getString(_unlockKey) == ownerEmail;
  }

  static Future<bool> unlock({
    required HubsomUser? user,
    required String password,
  }) async {
    if (!isOwner(user) || !checkPassword(password)) return false;
    await LocalStore.setString(_unlockKey, ownerEmail);
    return true;
  }

  static Future<void> lock() => LocalStore.setString(_unlockKey, null);
}
