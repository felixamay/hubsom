import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/live_gift.dart';
import '../../models/user.dart';
import 'admin_treasury_store.dart';
import 'cloud_store.dart';
import 'local_commerce_store.dart';
import 'local_store.dart';

/// Purchasable live-gift points and in-session sends (device + cloud vault).
class GiftStore {
  GiftStore._();

  static const _ledgerKey = 'localGiftLedger';
  static const _hostEarningsKey = 'localGiftHostEarnings';
  static const _uuid = Uuid();

  static HubsomUser? _sessionUser() {
    final raw = LocalStore.userJson;
    if (raw == null || raw.isEmpty) return null;
    try {
      return HubsomUser.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<HubsomUser> persistUser(HubsomUser user) async {
    final session = _sessionUser();
    if (session != null && session.id == user.id) {
      await LocalStore.setUserJson(jsonEncode(user.toJson()));
    }
    final vault = LocalStore.loadCredentialVault();
    final email = user.email.toLowerCase();
    final entry = vault[email];
    if (entry is Map) {
      entry['userJson'] = user.toJson();
      vault[email] = entry;
      await LocalStore.saveCredentialVault(vault);
      try {
        await CloudStore.putAccount(email, {
          ...Map<String, dynamic>.from(entry),
          'userJson': user.toJson(),
          'email': email,
        });
      } catch (_) {}
    }
    return user;
  }

  static List<GiftLedgerEntry> listLedger({String? userId}) {
    final raw = LocalStore.getString(_ledgerKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      final rows = list
          .map((e) => GiftLedgerEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (userId == null) return rows;
      return rows.where((e) => e.userId == userId).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Gifts received as a live host (keyed by seller id).
  static List<GiftLedgerEntry> receivedFor(String sellerId) {
    if (sellerId.isEmpty) return const [];
    return listLedger()
        .where(
          (e) =>
              e.kind == 'send' &&
              e.hostSellerId == sellerId &&
              (e.hostShareGhs == null || e.hostShareGhs! > 0),
        )
        .toList();
  }

  static double pendingEarningsGhs(HubsomUser user) {
    final sellerId = user.sellerId ?? '';
    final stored = sellerId.isEmpty ? 0.0 : hostEarnings(sellerId);
    final fromUser = user.giftEarningsGhs;
    final received = sellerId.isEmpty
        ? 0.0
        : receivedFor(sellerId).fold<double>(
            0,
            (sum, e) =>
                sum + (e.hostShareGhs ?? GiftCatalog.hostShareGhs(e.points)),
          );
    final withdrawn = listLedger()
        .where((e) => e.kind == 'withdraw' && e.userId == user.id)
        .fold<double>(0, (sum, e) => sum + (e.priceGhs ?? 0));
    // stored / giftEarningsGhs are remaining balances on one device.
    // received is lifetime gross. Taking max(stored, received - withdrawn)
    // ignored cash-outs against a stale host-earnings map, so a second
    // phone paid the same gifts out again.
    final gross = [fromUser, stored, received]
        .reduce((a, b) => a > b ? a : b);
    final pending = gross - withdrawn;
    return pending < 0 ? 0 : pending;
  }

  /// Pull gift sends and host balances written on other devices.
  static Future<void> pullCloud({String? sellerId}) async {
    if (!CloudStore.useNetwork) return;
    try {
      final remote = await CloudStore.listDocs(CloudStore.giftLedger);
      if (remote.isNotEmpty) {
        final merged = CloudStore.mergeDocsById(
          localKey: _ledgerKey,
          incoming: remote,
        );
        await LocalStore.setString(_ledgerKey, jsonEncode(merged));
      }
    } catch (_) {}
    final id = sellerId?.trim() ?? '';
    if (id.isEmpty) return;
    try {
      final row = await CloudStore.getDoc(CloudStore.giftHostEarnings, id);
      if (row == null || row.isEmpty) return;
      await applyCloudHostEarnings(
        sellerId: id,
        balanceGhs: (row['balanceGhs'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {}
  }

  /// Cloud remaining balance is authoritative, including 0 after a cash-out.
  /// Only increasing let a second device keep the pre-withdraw amount.
  @visibleForTesting
  static Future<void> applyCloudHostEarnings({
    required String sellerId,
    required double balanceGhs,
  }) async {
    if (sellerId.isEmpty) return;
    final map = _hostEarnings();
    map[sellerId] = balanceGhs < 0 ? 0 : balanceGhs;
    await LocalStore.setString(_hostEarningsKey, jsonEncode(map));
  }

  static Future<HubsomUser> withdrawEarnings(HubsomUser user) async {
    final pending = pendingEarningsGhs(user);
    if (pending <= 0.001) {
      throw StateError('No gift earnings to withdraw yet');
    }
    final sellerId = user.sellerId ?? '';
    final next = user.copyWith(
      walletBalanceGhs: user.walletBalanceGhs + pending,
      giftEarningsGhs: 0,
    );
    final saved = await persistUser(next);
    if (sellerId.isNotEmpty) {
      final map = _hostEarnings();
      map[sellerId] = 0;
      await _saveHostEarnings(map);
      await _writeHostEarningsCloud(sellerId, 0);
    }
    final rows = List<GiftLedgerEntry>.from(listLedger());
    rows.insert(
      0,
      GiftLedgerEntry(
        id: 'gwd_${_uuid.v4().substring(0, 8)}',
        userId: saved.id,
        kind: 'withdraw',
        points: 0,
        priceGhs: pending,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    await _saveLedger(rows);
    return saved;
  }

  static Future<void> _saveLedger(List<GiftLedgerEntry> rows) async {
    await LocalStore.setString(
      _ledgerKey,
      jsonEncode(rows.map((e) => e.toJson()).toList()),
    );
    try {
      await CloudStore.upsertDocs(
        CloudStore.giftLedger,
        rows.take(80).map((e) => e.toJson()).toList(),
      );
    } catch (_) {}
  }

  static Map<String, double> _hostEarnings() {
    final raw = LocalStore.getString(_hostEarningsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return map.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveHostEarnings(Map<String, double> map) async {
    await LocalStore.setString(_hostEarningsKey, jsonEncode(map));
  }

  static Future<void> _writeHostEarningsCloud(
    String sellerId,
    double balanceGhs,
  ) async {
    if (sellerId.isEmpty || !CloudStore.useNetwork) return;
    try {
      await CloudStore.upsertDocs(CloudStore.giftHostEarnings, [
        {
          'id': sellerId,
          'sellerId': sellerId,
          'balanceGhs': balanceGhs,
        },
      ]);
    } catch (_) {}
  }

  static Future<void> _addHostEarnings(String sellerId, double share) async {
    var current = hostEarnings(sellerId);
    if (CloudStore.useNetwork) {
      try {
        final row = await CloudStore.getDoc(
          CloudStore.giftHostEarnings,
          sellerId,
        );
        final cloud = (row?['balanceGhs'] as num?)?.toDouble() ?? 0;
        if (cloud > current) current = cloud;
      } catch (_) {}
    }
    final next = current + share;
    final map = _hostEarnings();
    map[sellerId] = next;
    await _saveHostEarnings(map);
    await _writeHostEarningsCloud(sellerId, next);
  }

  static double hostEarnings(String sellerId) => _hostEarnings()[sellerId] ?? 0;

  static Future<HubsomUser> buyPoints({
    required HubsomUser user,
    required GiftPointPack pack,
    required String paymentMethod,
  }) async {
    if (pack.points <= 0 || pack.priceGhs <= 0) {
      throw StateError('Choose a gift point pack');
    }
    var next = user;
    if (paymentMethod == 'wallet') {
      if (user.walletBalanceGhs + 0.001 < pack.priceGhs) {
        throw StateError(
          'Wallet needs ${pack.priceGhs.toStringAsFixed(0)} GHS for this pack',
        );
      }
      next = user.copyWith(
        walletBalanceGhs: user.walletBalanceGhs - pack.priceGhs,
        giftPoints: user.giftPoints + pack.points,
      );
    } else {
      next = user.copyWith(giftPoints: user.giftPoints + pack.points);
    }
    final saved = await persistUser(next);
    final rows = List<GiftLedgerEntry>.from(listLedger());
    rows.insert(
      0,
      GiftLedgerEntry(
        id: 'gpt_${_uuid.v4().substring(0, 8)}',
        userId: saved.id,
        kind: 'purchase',
        points: pack.points,
        priceGhs: pack.priceGhs,
        paymentMethod: paymentMethod,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    await _saveLedger(rows);
    if (paymentMethod != 'wallet') {
      try {
        await AdminTreasuryStore.recordIntake(
          source: 'gift',
          refId: rows.first.id,
          amountGhs: pack.priceGhs,
          commissionGhs: pack.priceGhs,
          buyerId: saved.id,
          note: 'Gift points paid to Hubsom Admin',
        );
      } catch (_) {}
    }
    return saved;
  }

  static Future<({HubsomUser user, LiveGift gift, GiftLedgerEntry entry})>
      sendGift({
    required HubsomUser sender,
    required String streamId,
    required String giftId,
  }) async {
    final gift = GiftCatalog.byId(giftId);
    if (gift == null) throw StateError('Unknown gift');
    if (sender.giftPoints < gift.costPoints) {
      throw StateError(
        'You need ${gift.costPoints} points for ${gift.name}. Buy points first.',
      );
    }
    final stream = LocalCommerceStore.getStream(streamId);
    if (stream == null || !stream.isLive) {
      throw StateError('Gifts can only be sent while the show is live');
    }
    final selfGift = stream.hosts.any((h) => h.id == sender.id) ||
        (sender.sellerId != null &&
            sender.sellerId!.isNotEmpty &&
            sender.sellerId == stream.sellerId);

    final next = sender.copyWith(
      giftPoints: sender.giftPoints - gift.costPoints,
    );
    final saved = await persistUser(next);

    final share = GiftCatalog.hostShareGhs(gift.costPoints);
    if (!selfGift) {
      await _addHostEarnings(stream.sellerId, share);
      await _creditHostUser(stream.sellerId, share);
    }

    final entry = GiftLedgerEntry(
      id: 'gft_${_uuid.v4().substring(0, 8)}',
      userId: saved.id,
      kind: 'send',
      points: gift.costPoints,
      streamId: streamId,
      giftId: gift.id,
      giftName: gift.name,
      hostSellerId: stream.sellerId,
      senderName: saved.name,
      hostShareGhs: selfGift ? 0 : share,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    final rows = List<GiftLedgerEntry>.from(listLedger());
    rows.insert(0, entry);
    await _saveLedger(rows);
    return (user: saved, gift: gift, entry: entry);
  }

  static Future<void> _creditHostUser(String sellerId, double ghs) async {
    final seller = LocalCommerceStore.getSeller(sellerId);
    final ownerId = seller?.ownerUserId;
    if (ownerId == null || ownerId.isEmpty) return;
    final vault = LocalStore.loadCredentialVault();
    for (final row in vault.values) {
      if (row is! Map) continue;
      final raw = row['userJson'];
      if (raw is! Map) continue;
      try {
        var host = HubsomUser.fromJson(Map<String, dynamic>.from(raw));
        if (host.id != ownerId && host.sellerId != sellerId) continue;
        host = host.copyWith(giftEarningsGhs: host.giftEarningsGhs + ghs);
        await persistUser(host);
        return;
      } catch (_) {}
    }
    final session = _sessionUser();
    if (session != null &&
        (session.id == ownerId || session.sellerId == sellerId)) {
      await persistUser(
        session.copyWith(giftEarningsGhs: session.giftEarningsGhs + ghs),
      );
    }
  }
}
