import 'package:equatable/equatable.dart';

class Promotion extends Equatable {
  const Promotion({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.href,
    this.ctaLabel,
    this.tone,
    required this.placement,
    this.placements = const [],
    this.categorySlugs = const [],
    this.productIds = const [],
    this.active = true,
    this.priority = 0,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? href;
  final String? ctaLabel;
  final String? tone;
  final String placement; // landing | marketplace | category | product
  final List<String> placements;
  final List<String> categorySlugs;
  final List<String> productIds;
  final bool active;
  final int priority;

  List<String> get placementIds {
    if (placements.isNotEmpty) return placements;
    return placement.isEmpty ? const ['landing'] : [placement];
  }

  bool matchesPlacement(String slot) => placementIds.contains(slot);

  factory Promotion.fromJson(Map<String, dynamic> json) {
    final slots = _readPlacements(json);
    return Promotion(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      imageUrl: json['imageUrl'] as String? ?? json['image'] as String?,
      href: json['href'] as String? ?? json['link'] as String?,
      ctaLabel: json['ctaLabel'] as String?,
      tone: json['tone'] as String?,
      placement: slots.isNotEmpty ? slots.first : 'landing',
      placements: slots,
      categorySlugs: _readStrings(json['categorySlugs']),
      productIds: _readStrings(json['productIds']),
      active: json['active'] as bool? ?? true,
      priority: (json['priority'] as num? ?? json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (href != null) 'href': href,
        if (ctaLabel != null) 'ctaLabel': ctaLabel,
        if (tone != null) 'tone': tone,
        'placement': placement,
        'placements': placementIds,
        'categorySlugs': categorySlugs,
        'productIds': productIds,
        'active': active,
        'priority': priority,
        'sortOrder': priority,
      };

  Promotion copyWith({
    String? title,
    String? subtitle,
    String? imageUrl,
    String? href,
    String? ctaLabel,
    String? tone,
    String? placement,
    List<String>? placements,
    List<String>? categorySlugs,
    List<String>? productIds,
    bool? active,
    int? priority,
  }) {
    final nextPlacements = placements ?? this.placements;
    return Promotion(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
      href: href ?? this.href,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      tone: tone ?? this.tone,
      placement: placement ??
          (nextPlacements.isNotEmpty ? nextPlacements.first : this.placement),
      placements: nextPlacements,
      categorySlugs: categorySlugs ?? this.categorySlugs,
      productIds: productIds ?? this.productIds,
      active: active ?? this.active,
      priority: priority ?? this.priority,
    );
  }

  static List<String> _readPlacements(Map<String, dynamic> json) {
    final multi = json['placements'];
    if (multi is List && multi.isNotEmpty) {
      return multi.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
    }
    final one = json['placement'] as String?;
    if (one != null && one.trim().isNotEmpty) return [one.trim()];
    return const ['landing'];
  }

  static List<String> _readStrings(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
  }

  @override
  List<Object?> get props =>
      [id, title, placement, placements, active, priority];
}
