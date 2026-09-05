import 'package:equatable/equatable.dart';

import 'order.dart';

/// Admin-created deal sent to shoppers from their purchase history.
class PurchaseOffer extends Equatable {
  const PurchaseOffer({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.ctaLabel = 'Shop now',
    this.href = '/marketplace',
    this.imageUrl,
    this.productIds = const [],
    this.categorySlugs = const [],
    this.discountPct = 0,
    this.active = true,
    this.createdAt = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final String href;
  final String? imageUrl;
  /// Show to buyers who purchased any of these products.
  final List<String> productIds;
  /// Show to buyers who purchased in any of these categories.
  final List<String> categorySlugs;
  final int discountPct;
  final bool active;
  final String createdAt;

  bool get hasTarget => productIds.isNotEmpty || categorySlugs.isNotEmpty;

  factory PurchaseOffer.fromJson(Map<String, dynamic> json) {
    final placements = (json['placements'] as List?)?.cast<String>() ?? const [];
    final placement = json['placement'] as String? ?? '';
    final isOffer = placement == 'offers' ||
        placement == 'dashboard' ||
        placements.contains('offers') ||
        placements.contains('dashboard') ||
        json['kind'] == 'purchase-offer';
    return PurchaseOffer(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      ctaLabel: json['ctaLabel'] as String? ?? 'Shop now',
      href: json['href'] as String? ?? json['link'] as String? ?? '/marketplace',
      imageUrl: json['imageUrl'] as String? ?? json['image'] as String?,
      productIds: (json['productIds'] as List?)?.cast<String>() ?? const [],
      categorySlugs:
          (json['categorySlugs'] as List?)?.cast<String>() ?? const [],
      discountPct: (json['discountPct'] as num?)?.toInt() ??
          (json['priority'] as num?)?.toInt() ??
          0,
      active: json['active'] as bool? ?? isOffer || json['id'] != null,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'ctaLabel': ctaLabel,
        'href': href,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
        'productIds': productIds,
        'categorySlugs': categorySlugs,
        if (discountPct > 0) 'discountPct': discountPct,
        'active': active,
        'kind': 'purchase-offer',
        'placements': const ['offers'],
        if (createdAt.isNotEmpty) 'createdAt': createdAt,
      };

  /// Users with no purchases never see an offer.
  /// Untargeted offers go to anyone who has bought something.
  bool matchesPurchases(Iterable<Order> purchases) {
    if (!active || id.isEmpty || title.trim().isEmpty) return false;
    final products = purchasedProductIds(purchases);
    final categories = purchasedCategories(purchases);
    if (products.isEmpty && categories.isEmpty) return false;
    if (!hasTarget) return true;
    if (productIds.any(products.contains)) return true;
    if (categorySlugs.any(categories.contains)) return true;
    return false;
  }

  String reasonFor(Iterable<Order> purchases) {
    for (final order in purchases) {
      for (final line in order.lines) {
        if (productIds.contains(line.productId) && line.name.isNotEmpty) {
          return 'Because you bought ${line.name}';
        }
      }
    }
    for (final order in purchases) {
      for (final line in order.lines) {
        if (categorySlugs.contains(line.category) && line.name.isNotEmpty) {
          return 'Because you bought ${line.name}';
        }
      }
    }
    if (purchasedProductIds(purchases).isNotEmpty) {
      return 'Because of your Hubsom purchases';
    }
    return '';
  }

  static Set<String> purchasedProductIds(Iterable<Order> purchases) {
    return {
      for (final order in purchases)
        for (final line in order.lines)
          if (line.productId.isNotEmpty) line.productId,
    };
  }

  static Set<String> purchasedCategories(Iterable<Order> purchases) {
    return {
      for (final order in purchases)
        for (final line in order.lines)
          if (line.category.isNotEmpty) line.category,
    };
  }

  static List<PurchaseOffer> matching(
    Iterable<PurchaseOffer> offers,
    Iterable<Order> purchases,
  ) {
    return offers.where((o) => o.matchesPurchases(purchases)).toList();
  }

  @override
  List<Object?> get props => [id, title, href, active];
}
