import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../models/promotion.dart';
import 'cloud_store.dart';
import 'local_store.dart';

/// HubsomAdmin promotions stored on-device and synced to CloudStore.
class LocalPromotionStore {
  LocalPromotionStore._();

  static const _key = 'promotions';
  static const _uuid = Uuid();

  static const placements = <({String id, String label, String description})>[
    (
      id: 'landing',
      label: 'Landing page',
      description: 'Home / landing promo rail',
    ),
    (
      id: 'marketplace',
      label: 'Marketplace',
      description: 'Products listing',
    ),
    (
      id: 'category',
      label: 'Category pages',
      description: 'Category browse and detail',
    ),
    (
      id: 'product',
      label: 'Product pages',
      description: 'Product detail pages',
    ),
  ];

  static List<Promotion> all() {
    final raw = LocalStore.getString(_key);
    if (raw == null || raw.isEmpty) return <Promotion>[];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Promotion.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((p) => p.id.isNotEmpty && p.title.isNotEmpty)
          .toList()
        ..sort((a, b) => b.priority.compareTo(a.priority));
    } catch (_) {
      return <Promotion>[];
    }
  }

  static List<Promotion> forPlacement(String placement) {
    return all()
        .where((p) => p.active && p.matchesPlacement(placement))
        .toList();
  }

  static Future<void> _persist(List<Promotion> rows) async {
    await LocalStore.setString(
      _key,
      jsonEncode(rows.map((e) => e.toJson()).toList()),
    );
    try {
      await CloudStore.upsertDocs(
        CloudStore.promotions,
        rows.map((e) => e.toJson()).toList(),
      );
    } catch (_) {}
  }

  static Future<Promotion> upsert(Promotion promo) async {
    final trimmed = promo.title.trim();
    if (trimmed.isEmpty) {
      throw StateError('Add a title for this promotion');
    }
    final slots = promo.placementIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (slots.isEmpty) {
      throw StateError('Select at least one placement');
    }
    final next = promo.copyWith(
      title: trimmed,
      subtitle: promo.subtitle?.trim(),
      href: (promo.href ?? '').trim().isEmpty ? '/marketplace' : promo.href?.trim(),
      placements: slots,
      placement: slots.first,
    );
    final rows = [...all()];
    final idx = rows.indexWhere((p) => p.id == next.id);
    if (idx >= 0) {
      rows[idx] = next;
    } else {
      rows.insert(0, next);
    }
    await _persist(rows);
    return next;
  }

  static Future<Promotion> create({
    required String title,
    String? subtitle,
    String? imageUrl,
    String? href,
    String? ctaLabel,
    String? tone,
    List<String> placements = const ['landing'],
    List<String> categorySlugs = const [],
    List<String> productIds = const [],
    bool active = true,
    int priority = 100,
  }) {
    return upsert(
      Promotion(
        id: 'promo_${_uuid.v4().replaceAll('-', '').substring(0, 10)}',
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl,
        href: href,
        ctaLabel: ctaLabel,
        tone: tone,
        placement: placements.isNotEmpty ? placements.first : 'landing',
        placements: placements,
        categorySlugs: categorySlugs,
        productIds: productIds,
        active: active,
        priority: priority,
      ),
    );
  }

  static Future<void> remove(String id) async {
    final rows = all().where((p) => p.id != id).toList();
    await _persist(rows);
  }

  static Future<void> mergeRemote(Iterable<Promotion> remote) async {
    if (remote.isEmpty) return;
    final byId = {for (final p in all()) p.id: p};
    var changed = false;
    for (final promo in remote) {
      if (promo.id.isEmpty) continue;
      if (byId[promo.id] == promo) continue;
      byId[promo.id] = promo;
      changed = true;
    }
    if (changed) await _persist(byId.values.toList());
  }

  static Future<void> pullCloud() async {
    try {
      final rows = await CloudStore.listDocs(CloudStore.promotions);
      await mergeRemote(rows.map(Promotion.fromJson));
    } catch (_) {}
  }
}
