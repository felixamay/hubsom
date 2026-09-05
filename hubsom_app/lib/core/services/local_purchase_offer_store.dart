import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../models/order.dart';
import '../../models/purchase_offer.dart';
import 'cloud_store.dart';
import 'local_store.dart';

/// Admin purchase offers stored on-device and synced to CloudStore.
class LocalPurchaseOfferStore {
  LocalPurchaseOfferStore._();

  static const _key = 'purchaseOffers';
  static const _uuid = Uuid();

  static List<PurchaseOffer> all() {
    final raw = LocalStore.getString(_key);
    if (raw == null || raw.isEmpty) return <PurchaseOffer>[];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map(
            (e) => PurchaseOffer.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .where((o) => o.id.isNotEmpty)
          .toList();
    } catch (_) {
      return <PurchaseOffer>[];
    }
  }

  static Future<void> _persist(List<PurchaseOffer> rows) async {
    await LocalStore.setString(
      _key,
      jsonEncode(rows.map((e) => e.toJson()).toList()),
    );
    try {
      await CloudStore.upsertDocs(
        CloudStore.purchaseOffers,
        rows.map((e) => e.toJson()).toList(),
      );
    } catch (_) {}
  }

  static Future<PurchaseOffer> upsert(PurchaseOffer offer) async {
    final rows = [...all()];
    final idx = rows.indexWhere((o) => o.id == offer.id);
    if (idx >= 0) {
      rows[idx] = offer;
    } else {
      rows.insert(0, offer);
    }
    await _persist(rows);
    return offer;
  }

  static Future<PurchaseOffer> create({
    required String title,
    String subtitle = '',
    String ctaLabel = 'Shop now',
    String href = '/marketplace',
    String? imageUrl,
    List<String> productIds = const [],
    List<String> categorySlugs = const [],
    int discountPct = 0,
  }) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw StateError('Add a title for this offer');
    }
    return upsert(
      PurchaseOffer(
        id: 'offer_${_uuid.v4().replaceAll('-', '').substring(0, 10)}',
        title: trimmed,
        subtitle: subtitle.trim(),
        ctaLabel: ctaLabel.trim().isEmpty ? 'Shop now' : ctaLabel.trim(),
        href: href.trim().isEmpty ? '/marketplace' : href.trim(),
        imageUrl: imageUrl,
        productIds: productIds.where((e) => e.trim().isNotEmpty).toList(),
        categorySlugs: categorySlugs.where((e) => e.trim().isNotEmpty).toList(),
        discountPct: discountPct < 0 ? 0 : discountPct,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  static Future<void> mergeRemote(Iterable<PurchaseOffer> remote) async {
    if (remote.isEmpty) return;
    final byId = {for (final o in all()) o.id: o};
    var changed = false;
    for (final offer in remote) {
      if (offer.id.isEmpty) continue;
      if (byId[offer.id] == offer) continue;
      byId[offer.id] = offer;
      changed = true;
    }
    if (changed) await _persist(byId.values.toList());
  }

  static Future<void> pullCloud() async {
    try {
      final rows = await CloudStore.listDocs(CloudStore.purchaseOffers);
      await mergeRemote(rows.map(PurchaseOffer.fromJson));
    } catch (_) {}
  }

  static List<PurchaseOffer> forPurchases(Iterable<Order> purchases) {
    return PurchaseOffer.matching(all(), purchases);
  }
}
