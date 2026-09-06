import 'dart:convert';

import '../../core/auth/afia_access.dart';
import '../../models/user.dart';
import 'cloud_store.dart';
import 'local_store.dart';

class AdminAccount {
  const AdminAccount({
    required this.email,
    required this.user,
    this.raw = const {},
  });

  final String email;
  final HubsomUser user;
  final Map<String, dynamic> raw;

  bool get isOwner => AfiaAccess.isOwnerEmail(email);
}

/// Hubsom accounts from Firestore plus the on-device vault.
abstract final class AdminAccountStore {
  static const _cacheKey = 'adminAccountsCache';

  static List<AdminAccount> cached() {
    final byEmail = <String, AdminAccount>{};
    _mergeVault(byEmail);
    _mergeRows(byEmail, _readCache());
    return _sorted(byEmail.values);
  }

  static Future<List<AdminAccount>> list() async {
    final byEmail = <String, AdminAccount>{};
    _mergeVault(byEmail);
    _mergeRows(byEmail, _readCache());
    if (CloudStore.useNetwork) {
      try {
        final remote = await CloudStore.listDocs(CloudStore.accounts);
        _mergeRows(byEmail, remote);
        await LocalStore.setString(_cacheKey, jsonEncode(remote));
      } catch (_) {}
    }
    return _sorted(byEmail.values);
  }

  static Future<AdminAccount> save(HubsomUser user) async {
    final email = AfiaAccess.normalizeEmail(user.email);
    if (email.isEmpty) throw StateError('Account email is required');
    final existing = _recordFor(email);
    final next = Map<String, dynamic>.from(existing)
      ..['email'] = email
      ..['name'] = user.name
      ..['role'] = user.role
      ..['suspended'] = user.suspended
      ..['userJson'] = user.toJson();
    final vault = LocalStore.loadCredentialVault();
    vault[email] = next;
    await LocalStore.saveCredentialVault(vault);
    if (CloudStore.useNetwork) {
      try {
        await CloudStore.putAccount(email, next);
      } catch (_) {}
    }
    await _writeCacheAccount(next);
    return AdminAccount(email: email, user: user, raw: next);
  }

  static Future<void> setSuspended(String email, bool suspended) async {
    final id = AfiaAccess.normalizeEmail(email);
    final match = (await list()).where((a) => a.email == id);
    if (match.isEmpty) throw StateError('Account not found');
    final row = match.first;
    if (row.isOwner) {
      throw StateError('The Afia owner account cannot be suspended');
    }
    await save(row.user.copyWith(suspended: suspended));
  }

  static Future<void> delete(String email) async {
    final id = AfiaAccess.normalizeEmail(email);
    if (AfiaAccess.isOwnerEmail(id)) {
      throw StateError('The Afia owner account cannot be deleted');
    }
    final vault = LocalStore.loadCredentialVault();
    vault.remove(id);
    await LocalStore.saveCredentialVault(vault);
    if (CloudStore.useNetwork) {
      try {
        await CloudStore.deleteDoc(
          CloudStore.accounts,
          CloudStore.accountDocId(id),
        );
      } catch (_) {}
    }
    final cache = _readCache()
        .where((row) => AfiaAccess.normalizeEmail('${row['email'] ?? ''}') != id)
        .toList();
    await LocalStore.setString(_cacheKey, jsonEncode(cache));
  }

  static Map<String, dynamic> _recordFor(String email) {
    final vault = LocalStore.loadCredentialVault()[email];
    if (vault is Map) return Map<String, dynamic>.from(vault);
    for (final row in _readCache()) {
      if (AfiaAccess.normalizeEmail('${row['email'] ?? ''}') == email) {
        return Map<String, dynamic>.from(row);
      }
    }
    return {'email': email};
  }

  static void _mergeVault(Map<String, AdminAccount> byEmail) {
    LocalStore.loadCredentialVault().forEach((key, value) {
      if (value is! Map) return;
      final account = _fromRecord(Map<String, dynamic>.from(value), key.toString());
      if (account != null) byEmail[account.email] = account;
    });
  }

  static void _mergeRows(
    Map<String, AdminAccount> byEmail,
    List<Map<String, dynamic>> rows,
  ) {
    for (final row in rows) {
      final account = _fromRecord(row, '${row['email'] ?? row['id'] ?? ''}');
      if (account != null) byEmail[account.email] = account;
    }
  }

  static AdminAccount? _fromRecord(Map<String, dynamic> row, String fallbackEmail) {
    final rawUser = row['userJson'];
    HubsomUser? user;
    if (rawUser is Map) {
      try {
        user = HubsomUser.fromJson(Map<String, dynamic>.from(rawUser));
      } catch (_) {}
    }
    user ??= HubsomUser(
      id: '${row['id'] ?? fallbackEmail}',
      email: fallbackEmail,
      name: '${row['name'] ?? fallbackEmail}',
      role: '${row['role'] ?? 'buyer'}',
      suspended: row['suspended'] as bool? ?? false,
    );
    final email = AfiaAccess.normalizeEmail(
      user.email.isEmpty ? fallbackEmail : user.email,
    );
    if (email.isEmpty || !email.contains('@')) return null;
    final suspended = row['suspended'] as bool? ?? user.suspended;
    return AdminAccount(
      email: email,
      user: user.copyWith(suspended: suspended),
      raw: row,
    );
  }

  static List<Map<String, dynamic>> _readCache() {
    final raw = LocalStore.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _writeCacheAccount(Map<String, dynamic> row) async {
    final email = AfiaAccess.normalizeEmail('${row['email'] ?? ''}');
    final rows = [
      row,
      ..._readCache().where(
        (e) => AfiaAccess.normalizeEmail('${e['email'] ?? ''}') != email,
      ),
    ];
    await LocalStore.setString(_cacheKey, jsonEncode(rows));
  }

  static List<AdminAccount> _sorted(Iterable<AdminAccount> rows) {
    return [...rows]..sort((a, b) {
        if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
        return a.user.name.toLowerCase().compareTo(b.user.name.toLowerCase());
      });
  }
}
