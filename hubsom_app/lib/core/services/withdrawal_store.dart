import 'dart:convert';

import '../../models/withdrawal_request.dart';
import 'cloud_store.dart';
import 'local_store.dart';

/// User cash-out requests. Stay pending until an admin marks them processed.
abstract final class WithdrawalStore {
  static const key = 'withdrawals';

  static List<WithdrawalRequest> listAll() {
    final raw = LocalStore.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      final rows = list
          .whereType<Map>()
          .map((e) => WithdrawalRequest.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList();
      rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return rows;
    } catch (_) {
      return const [];
    }
  }

  static List<WithdrawalRequest> forUser(String userId) =>
      listAll().where((e) => e.userId == userId).toList();

  static List<WithdrawalRequest> pending() =>
      listAll().where((e) => e.isPending).toList();

  static WithdrawalRequest? byId(String id) {
    for (final row in listAll()) {
      if (row.id == id) return row;
    }
    return null;
  }

  static Future<void> mergeCloud() async {
    try {
      final remote = await CloudStore.listDocs(CloudStore.withdrawals);
      if (remote.isEmpty) return;
      final byId = <String, WithdrawalRequest>{
        for (final row in listAll()) row.id: row,
      };
      for (final row in remote) {
        try {
          final next = WithdrawalRequest.fromJson(row);
          if (next.id.isEmpty) continue;
          byId[next.id] = next;
        } catch (_) {}
      }
      await _save(byId.values.toList());
    } catch (_) {}
  }

  static Future<WithdrawalRequest> upsert(WithdrawalRequest row) async {
    final byId = {for (final e in listAll()) e.id: e};
    byId[row.id] = row;
    await _save(byId.values.toList());
    return row;
  }

  static Future<WithdrawalRequest> markProcessed(String id) async {
    final current = byId(id);
    if (current == null) throw StateError('Withdrawal not found');
    if (current.isProcessed) return current;
    return upsert(
      current.copyWith(
        status: 'processed',
        processedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  static Future<void> _save(List<WithdrawalRequest> rows) async {
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await LocalStore.setString(
      key,
      jsonEncode(rows.map((e) => e.toJson()).toList()),
    );
    try {
      await CloudStore.upsertDocs(
        CloudStore.withdrawals,
        rows.map((e) => e.toJson()).toList(),
      );
    } catch (_) {}
  }
}
