import 'package:equatable/equatable.dart';

class FlashSale extends Equatable {
  const FlashSale({required this.endsAt, required this.discountPct});
  final String endsAt;
  final int discountPct;

  factory FlashSale.fromJson(Map<String, dynamic> json) => FlashSale(
        endsAt: json['endsAt'] as String,
        discountPct: (json['discountPct'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'endsAt': endsAt,
        'discountPct': discountPct,
      };

  /// True while the sale window is still open.
  bool get isActive {
    if (discountPct <= 0) return false;
    final end = DateTime.tryParse(endsAt);
    if (end == null) return true;
    return DateTime.now().toUtc().isBefore(end.toUtc());
  }

  @override
  List<Object?> get props => [endsAt, discountPct];
}

class Product extends Equatable {
  const Product({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.category,
    required this.priceGhs,
    this.compareAtGhs,
    this.currency = 'GHS',
    required this.images,
    required this.sellerId,
    required this.stock,
    this.rating = 0,
    this.reviewCount = 0,
    this.tags = const [],
    this.flashSale,
    this.supports = const [],
    this.hasDemoVideo = false,
    this.demoVideoUrl,
    this.auctionOnly = false,
  });

  final String id;
  final String slug;
  final String name;
  final String description;
  final String category;
  final double priceGhs;
  final double? compareAtGhs;
  final String currency;
  final List<String> images;
  final String sellerId;
  final int stock;
  final double rating;
  final int reviewCount;
  final List<String> tags;
  final FlashSale? flashSale;
  final List<String> supports;
  /// Short product demo (≤15s) for sellers who are not going live.
  final bool hasDemoVideo;
  /// Remote/demo URL when not stored locally in Hive.
  final String? demoVideoUrl;
  /// Live-auction lot — created separately and hidden from the public store.
  final bool auctionOnly;

  bool get isAuctionLot => auctionOnly;

  double get effectivePrice {
    if (!hasActiveFlashSale) return priceGhs;
    return priceGhs * (1 - flashSale!.discountPct / 100);
  }

  bool get showsDemoVideo =>
      hasDemoVideo || (demoVideoUrl != null && demoVideoUrl!.trim().isNotEmpty);

  /// Active flash sale that shoppers should still see.
  bool get hasActiveFlashSale => flashSale != null && flashSale!.isActive;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        slug: json['slug'] as String? ?? json['id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'miscellaneous',
        priceGhs: (json['priceGhs'] as num?)?.toDouble() ?? 0,
        compareAtGhs: (json['compareAtGhs'] as num?)?.toDouble(),
        currency: json['currency'] as String? ?? 'GHS',
        images: (json['images'] as List?)?.cast<String>() ?? const [],
        sellerId: json['sellerId'] as String? ?? '',
        stock: (json['stock'] as num?)?.toInt() ?? 0,
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
        flashSale: json['flashSale'] != null
            ? FlashSale.fromJson(Map<String, dynamic>.from(json['flashSale'] as Map))
            : null,
        supports: (json['supports'] as List?)?.cast<String>() ?? const [],
        hasDemoVideo: json['hasDemoVideo'] as bool? ?? false,
        demoVideoUrl: json['demoVideoUrl'] as String?,
        auctionOnly: json['auctionOnly'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'description': description,
        'category': category,
        'priceGhs': priceGhs,
        if (compareAtGhs != null) 'compareAtGhs': compareAtGhs,
        'currency': currency,
        'images': images,
        'sellerId': sellerId,
        'stock': stock,
        'rating': rating,
        'reviewCount': reviewCount,
        'tags': tags,
        if (flashSale != null) 'flashSale': flashSale!.toJson(),
        'supports': supports,
        'hasDemoVideo': hasDemoVideo,
        if (demoVideoUrl != null) 'demoVideoUrl': demoVideoUrl,
        if (auctionOnly) 'auctionOnly': true,
      };

  @override
  List<Object?> get props => [
        id,
        slug,
        name,
        priceGhs,
        sellerId,
        stock,
        hasDemoVideo,
        demoVideoUrl,
        flashSale,
        auctionOnly,
      ];

  Product copyWith({
    String? name,
    String? description,
    String? category,
    double? priceGhs,
    double? compareAtGhs,
    List<String>? images,
    int? stock,
    double? rating,
    int? reviewCount,
    List<String>? tags,
    List<String>? supports,
    bool? hasDemoVideo,
    String? demoVideoUrl,
    bool clearDemoVideoUrl = false,
    FlashSale? flashSale,
    bool clearFlashSale = false,
    String? slug,
    bool? auctionOnly,
  }) {
    return Product(
      id: id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      priceGhs: priceGhs ?? this.priceGhs,
      compareAtGhs: compareAtGhs ?? this.compareAtGhs,
      currency: currency,
      images: images ?? this.images,
      sellerId: sellerId,
      stock: stock ?? this.stock,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      tags: tags ?? this.tags,
      flashSale: clearFlashSale ? null : (flashSale ?? this.flashSale),
      supports: supports ?? this.supports,
      hasDemoVideo: hasDemoVideo ?? this.hasDemoVideo,
      demoVideoUrl:
          clearDemoVideoUrl ? null : (demoVideoUrl ?? this.demoVideoUrl),
      auctionOnly: auctionOnly ?? this.auctionOnly,
    );
  }
}
