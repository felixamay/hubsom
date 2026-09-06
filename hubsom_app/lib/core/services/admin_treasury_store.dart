import 'dart:convert';

import '../../core/auth/afia_access.dart';
import '../../core/constants/hubsom_commission.dart';
import '../../models/order.dart';
import '../../models/seller_payout.dart';
import '../../models/user.dart';
import 'admin_account_store.dart';
import 'cloud_store.dart';
import 'local_huber_store.dart';
import 'local_store.dart';

/// Buyer payments settle to Hubsom Admin. Sellers are paid 94% later.
abstract final class AdminTreasuryStore {
  static const payoutsKey = 'adminPayouts';
  static const intakesKey = 'adminIntakes';

  static String get adminEmail => AfiaAccess.ownerEmail;

  static List<SellerPayout> cachedPayouts() => _readPayouts();

  static List<TreasuryIntake> cachedIntakes() => _readIntakes();

  static TreasurySnapshot snapshot({
    List<SellerPayout>? payouts,
    List<TreasuryIntake>? intakes,
  }) {
    final pots = payouts ?? _readPayouts();
    final rows = intakes ?? _readIntakes();
    var collected = 0.0;
    var shipment = 0.0;
    var commission = 0.0;
    for (final row in rows) {
      collected += row.amountGhs;
      shipment += row.shipmentGhs;
      commission += row.commissionGhs;
    }
    var pending = 0.0;
    var paid = 0.0;
    for (final pot in pots) {
      if (pot.isPaid) {
        paid += pot.netGhs;
      } else {
        pending += pot.netGhs;
      }
    }
    return TreasurySnapshot(
      collectedGhs: HubsomCommission.roundGhs(collected),
      commissionGhs: HubsomCommission.roundGhs(commission),
      pendingPayoutsGhs: HubsomCommission.roundGhs(pending),
      paidOutGhs: HubsomCommission.roundGhs(paid),
      shipmentHeldGhs: HubsomCommission.roundGhs(shipment),
    );
  }

  static Future<List<SellerPayout>> listPayouts() async {
    await _hydrate();
    return _readPayouts();
  }

  static Future<List<TreasuryIntake>> listIntakes() async {
    await _hydrate();
    return _readIntakes();
  }

  static List<SellerPayout> payoutsFor(HubsomUser user) {
    return _readPayouts().where((p) => matchesSeller(p, user)).toList();
  }

  static bool matchesSeller(SellerPayout payout, HubsomUser user) {
    final sid = user.sellerId?.trim() ?? '';
    if (sid.isNotEmpty && payout.sellerId == sid) return true;
    if (payout.sellerUserId != null && payout.sellerUserId == user.id) {
      return true;
    }
    final email = AfiaAccess.normalizeEmail(user.email);
    if (email.isNotEmpty && AfiaAccess.normalizeEmail(payout.sellerEmail) == email) {
      return true;
    }
    return false;
  }

  static double pendingFor(HubsomUser user) => HubsomCommission.roundGhs(
        payoutsFor(user).where((p) => p.isPending).fold<double>(0, (s, p) => s + p.netGhs),
      );

  static Future<List<SellerPayout>> recordPaidOrder(Order order) async {
    if (!_collectable(order.status)) return const [];
    final merchandise = order.lines.fold<double>(0, (s, l) => s + l.lineTotalGhs);
    final shipment = order.shipmentFeeGhs > 0
        ? order.shipmentFeeGhs
        : order.lines.fold<double>(0, (s, l) => s + l.shipmentLineTotal);
    final createdAt = order.createdAt.isNotEmpty
        ? order.createdAt
        : DateTime.now().toUtc().toIso8601String();

    await recordIntake(
      source: 'order',
      refId: order.id,
      amountGhs: merchandise + shipment,
      merchandiseGhs: merchandise,
      shipmentGhs: shipment,
      commissionGhs: HubsomCommission.commissionOn(merchandise),
      buyerId: order.userId,
      createdAt: createdAt,
      note: 'Checkout held by $adminName',
    );

    final grouped = <String, List<OrderLine>>{};
    for (final line in order.lines) {
      final key = (line.sellerId ?? '').trim();
      grouped.putIfAbsent(key.isEmpty ? 'unassigned' : key, () => []).add(line);
    }

    final accounts = AdminAccountStore.cached();
    final existing = _readPayouts();
    final byId = {for (final p in existing) p.id: p};
    final written = <SellerPayout>[];

    for (final entry in grouped.entries) {
      final sales = entry.value.fold<double>(0, (s, l) => s + l.lineTotalGhs);
      if (sales <= 0) continue;
      final storeId = entry.key == 'unassigned' ? '' : entry.key;
      final store = _store(storeId);
      final account = _accountForSale(
        accounts,
        storeId: storeId,
        ownerUserId: store?.ownerUserId,
      );
      final id = payoutId(order.id, storeId.isEmpty ? 'unassigned' : storeId);
      final current = byId[id];
      if (current != null) {
        written.add(current);
        continue;
      }
      final payout = SellerPayout.fromSale(
        id: id,
        sellerId: storeId,
        sellerUserId: account?.user.id ?? store?.ownerUserId,
        sellerEmail: account?.email ?? '',
        sellerName: account?.user.name ?? store?.name ?? (storeId.isEmpty ? 'Unassigned seller' : storeId),
        orderId: order.id,
        salesGhs: sales,
        createdAt: createdAt,
      );
      byId[id] = payout;
      written.add(payout);
    }

    await _writePayouts(byId.values.toList());
    return written;
  }

  static String payoutId(String orderId, String sellerKey) =>
      'pot_${orderId}_${sellerKey.isEmpty ? 'unassigned' : sellerKey}';

  static Future<TreasuryIntake> recordIntake({
    required String source,
    required String refId,
    required double amountGhs,
    double merchandiseGhs = 0,
    double shipmentGhs = 0,
    double commissionGhs = 0,
    String? buyerId,
    String? createdAt,
    String note = '',
  }) async {
    final id = 'tin_${source}_$refId';
    final rows = _readIntakes();
    final existing = rows.where((e) => e.id == id);
    if (existing.isNotEmpty) return existing.first;
    final row = TreasuryIntake(
      id: id,
      source: source,
      refId: refId,
      amountGhs: HubsomCommission.roundGhs(amountGhs),
      merchandiseGhs: HubsomCommission.roundGhs(merchandiseGhs),
      shipmentGhs: HubsomCommission.roundGhs(shipmentGhs),
      commissionGhs: HubsomCommission.roundGhs(commissionGhs),
      buyerId: buyerId,
      createdAt: createdAt ?? DateTime.now().toUtc().toIso8601String(),
      note: note,
    );
    rows.insert(0, row);
    await _writeIntakes(rows);
    return row;
  }

  static Future<List<SellerPayout>> syncFromOrders() async {
    await _hydrate();
    final written = <SellerPayout>[];
    for (final order in LocalHuberStore.listOrders()) {
      written.addAll(await recordPaidOrder(order));
    }
    return _readPayouts();
  }

  static Future<SellerPayout> paySeller(String payoutId) async {
    final rows = _readPayouts();
    final idx = rows.indexWhere((p) => p.id == payoutId);
    if (idx < 0) throw StateError('Payout not found');
    final current = rows[idx];
    if (current.isPaid) return current;

    final accounts = await AdminAccountStore.list();
    final account = _accountForPayout(accounts, current);
    if (account == null) {
      throw StateError(
        'No Hubsom account for ${current.sellerName}. '
        'The seller must have an account before admin can pay them.',
      );
    }

    final credited = account.user.copyWith(
      walletBalanceGhs:
          HubsomCommission.roundGhs(account.user.walletBalanceGhs + current.netGhs),
    );
    await AdminAccountStore.save(credited);
    await _mirrorSessionWallet(credited);

    final paid = current.copyWith(
      status: 'paid',
      paidAt: DateTime.now().toUtc().toIso8601String(),
      sellerUserId: credited.id,
      sellerEmail: account.email,
      sellerName: credited.name,
      note: 'Paid by Hubsom Admin after ${HubsomCommission.percentLabel} commission',
    );
    rows[idx] = paid;
    await _writePayouts(rows);
    return paid;
  }

  static AdminAccount? accountForPayout(SellerPayout payout) =>
      _accountForPayout(AdminAccountStore.cached(), payout);

  static bool _collectable(String status) {
    switch (status.toLowerCase()) {
      case 'cancelled':
      case 'canceled':
      case 'refunded':
      case 'failed':
      case 'pending':
        return false;
      default:
        return true;
    }
  }

  static AdminAccount? _accountForSale(
    List<AdminAccount> accounts, {
    required String storeId,
    String? ownerUserId,
  }) {
    if (ownerUserId != null && ownerUserId.isNotEmpty) {
      final byOwner = accounts.where((a) => a.user.id == ownerUserId);
      if (byOwner.isNotEmpty) return byOwner.first;
    }
    if (storeId.isNotEmpty) {
      final byStore = accounts.where((a) => a.user.sellerId == storeId);
      if (byStore.isNotEmpty) return byStore.first;
    }
    return null;
  }

  static AdminAccount? _accountForPayout(
    List<AdminAccount> accounts,
    SellerPayout payout,
  ) {
    final userId = payout.sellerUserId?.trim() ?? '';
    if (userId.isNotEmpty) {
      final byId = accounts.where((a) => a.user.id == userId);
      if (byId.isNotEmpty) return byId.first;
    }
    final email = AfiaAccess.normalizeEmail(payout.sellerEmail);
    if (email.contains('@')) {
      final byEmail = accounts.where((a) => a.email == email);
      if (byEmail.isNotEmpty) return byEmail.first;
    }
    return _accountForSale(
      accounts,
      storeId: payout.sellerId,
      ownerUserId: payout.sellerUserId,
    );
  }

  static _StoreRef? _store(String sellerId) {
    if (sellerId.isEmpty) return null;
    final raw = LocalStore.getString('localSellers');
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List;
      for (final row in list) {
        if (row is! Map) continue;
        final data = Map<String, dynamic>.from(row);
        final id = '${data['id'] ?? ''}';
        final slug = '${data['slug'] ?? ''}';
        if (id == sellerId || slug == sellerId) {
          return _StoreRef(
            id: id,
            name: '${data['name'] ?? sellerId}',
            ownerUserId: data['ownerUserId'] as String?,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _mirrorSessionWallet(HubsomUser user) async {
    final raw = LocalStore.userJson;
    if (raw == null || raw.isEmpty) return;
    try {
      final session = HubsomUser.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (session.id != user.id &&
          AfiaAccess.normalizeEmail(session.email) !=
              AfiaAccess.normalizeEmail(user.email)) {
        return;
      }
      await LocalStore.setUserJson(jsonEncode(user.toJson()));
    } catch (_) {}
  }

  static List<SellerPayout> _readPayouts() =>
      _readList(payoutsKey).map(SellerPayout.fromJson).toList();

  static List<TreasuryIntake> _readIntakes() =>
      _readList(intakesKey).map(TreasuryIntake.fromJson).toList();

  static List<Map<String, dynamic>> _readList(String key) {
    final raw = LocalStore.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _writePayouts(List<SellerPayout> rows) async {
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await LocalStore.setString(
      payoutsKey,
      jsonEncode(rows.map((e) => e.toJson()).toList()),
    );
    try {
      await CloudStore.upsertDocs(
        CloudStore.adminPayouts,
        rows.map((e) => e.toJson()).toList(),
      );
    } catch (_) {}
  }

  static Future<void> _writeIntakes(List<TreasuryIntake> rows) async {
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await LocalStore.setString(
      intakesKey,
      jsonEncode(rows.map((e) => e.toJson()).toList()),
    );
    try {
      await CloudStore.upsertDocs(
        CloudStore.adminIntakes,
        rows.map((e) => e.toJson()).toList(),
      );
    } catch (_) {}
  }

  static Future<void> _hydrate() async {
    if (!CloudStore.useNetwork) return;
    try {
      final remotePayouts = await CloudStore.listDocs(CloudStore.adminPayouts);
      if (remotePayouts.isNotEmpty) {
        final byId = {for (final p in _readPayouts()) p.id: p};
        for (final row in remotePayouts) {
          try {
            final pot = SellerPayout.fromJson(row);
            if (pot.id.isEmpty) continue;
            final local = byId[pot.id];
            if (local == null || (pot.isPaid && !local.isPaid)) {
              byId[pot.id] = pot;
            }
          } catch (_) {}
        }
        await LocalStore.setString(
          payoutsKey,
          jsonEncode(byId.values.map((e) => e.toJson()).toList()),
        );
      }
    } catch (_) {}
    try {
      final remoteIntakes = await CloudStore.listDocs(CloudStore.adminIntakes);
      if (remoteIntakes.isNotEmpty) {
        final byId = {for (final p in _readIntakes()) p.id: p};
        for (final row in remoteIntakes) {
          try {
            final pot = TreasuryIntake.fromJson(row);
            if (pot.id.isEmpty) continue;
            byId.putIfAbsent(pot.id, () => pot);
          } catch (_) {}
        }
        await LocalStore.setString(
          intakesKey,
          jsonEncode(byId.values.map((e) => e.toJson()).toList()),
        );
      }
    } catch (_) {}
  }
}

class _StoreRef {
  const _StoreRef({
    required this.id,
    required this.name,
    this.ownerUserId,
  });

  final String id;
  final String name;
  final String? ownerUserId;
}

const adminName = HubsomCommission.adminName;
