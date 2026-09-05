import 'package:equatable/equatable.dart';

class LiveGift extends Equatable {
  const LiveGift({
    required this.id,
    required this.name,
    required this.emoji,
    required this.costPoints,
  });

  final String id;
  final String name;
  final String emoji;
  final int costPoints;

  factory LiveGift.fromJson(Map<String, dynamic> json) => LiveGift(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Gift',
        emoji: json['emoji'] as String? ?? '🎁',
        costPoints: (json['costPoints'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'costPoints': costPoints,
      };

  @override
  List<Object?> get props => [id, costPoints];

  /// Visual weight for the on-live send animation.
  GiftFxTier get fxTier {
    if (costPoints >= 499) return GiftFxTier.mega;
    if (costPoints >= 100) return GiftFxTier.large;
    if (costPoints >= 25) return GiftFxTier.medium;
    return GiftFxTier.small;
  }

  Duration get fxDuration => switch (fxTier) {
        GiftFxTier.mega => const Duration(milliseconds: 4200),
        GiftFxTier.large => const Duration(milliseconds: 3400),
        GiftFxTier.medium => const Duration(milliseconds: 2600),
        GiftFxTier.small => const Duration(milliseconds: 2000),
      };
}

enum GiftFxTier { small, medium, large, mega }

class GiftPointPack extends Equatable {
  const GiftPointPack({
    required this.id,
    required this.points,
    required this.priceGhs,
  });

  final String id;
  final int points;
  final double priceGhs;

  @override
  List<Object?> get props => [id, points, priceGhs];
}

class GiftLedgerEntry extends Equatable {
  const GiftLedgerEntry({
    required this.id,
    required this.userId,
    required this.kind,
    required this.points,
    required this.createdAt,
    this.priceGhs,
    this.paymentMethod,
    this.streamId,
    this.giftId,
    this.giftName,
    this.hostSellerId,
  });

  final String id;
  final String userId;
  final String kind; // purchase | send
  final int points;
  final String createdAt;
  final double? priceGhs;
  final String? paymentMethod;
  final String? streamId;
  final String? giftId;
  final String? giftName;
  final String? hostSellerId;

  factory GiftLedgerEntry.fromJson(Map<String, dynamic> json) =>
      GiftLedgerEntry(
        id: json['id'] as String,
        userId: json['userId'] as String? ?? '',
        kind: json['kind'] as String? ?? 'purchase',
        points: (json['points'] as num?)?.toInt() ?? 0,
        createdAt: json['createdAt'] as String? ?? '',
        priceGhs: (json['priceGhs'] as num?)?.toDouble(),
        paymentMethod: json['paymentMethod'] as String?,
        streamId: json['streamId'] as String?,
        giftId: json['giftId'] as String?,
        giftName: json['giftName'] as String?,
        hostSellerId: json['hostSellerId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'kind': kind,
        'points': points,
        'createdAt': createdAt,
        if (priceGhs != null) 'priceGhs': priceGhs,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (streamId != null) 'streamId': streamId,
        if (giftId != null) 'giftId': giftId,
        if (giftName != null) 'giftName': giftName,
        if (hostSellerId != null) 'hostSellerId': hostSellerId,
      };

  @override
  List<Object?> get props => [id, kind, points, streamId];
}

/// Hubsom live gifts — points are purchased, then spent in-session.
abstract final class GiftCatalog {
  static const gifts = <LiveGift>[
    LiveGift(id: 'rose', name: 'Rose', emoji: '🌹', costPoints: 1),
    LiveGift(id: 'heart', name: 'Heart', emoji: '❤️', costPoints: 10),
    LiveGift(id: 'star', name: 'Star', emoji: '⭐', costPoints: 25),
    LiveGift(id: 'trophy', name: 'Trophy', emoji: '🏆', costPoints: 50),
    LiveGift(id: 'crown', name: 'Crown', emoji: '👑', costPoints: 100),
    LiveGift(id: 'lion', name: 'Lion', emoji: '🦁', costPoints: 299),
    LiveGift(id: 'rocket', name: 'Rocket', emoji: '🚀', costPoints: 499),
    LiveGift(id: 'diamond', name: 'Diamond', emoji: '💎', costPoints: 999),
  ];

  static const packs = <GiftPointPack>[
    GiftPointPack(id: 'p100', points: 100, priceGhs: 10),
    GiftPointPack(id: 'p500', points: 500, priceGhs: 45),
    GiftPointPack(id: 'p1200', points: 1200, priceGhs: 99),
    GiftPointPack(id: 'p3000', points: 3000, priceGhs: 229),
  ];

  static LiveGift? byId(String id) {
    for (final g in gifts) {
      if (g.id == id) return g;
    }
    return null;
  }

  static GiftPointPack? packById(String id) {
    for (final p in packs) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 10 points ≈ 1 GHS. Hosts receive 80% of that value.
  static double hostShareGhs(int points) => (points / 10) * 0.8;

  /// Chat line written by [LiveRepository.sendGift].
  static LiveGift? parseFromChat(String text) {
    if (!text.contains('sent a ') || !text.contains(' pts)')) return null;
    for (final g in gifts) {
      if (text.contains(g.emoji) && text.contains(g.name)) return g;
    }
    return null;
  }
}
