import 'package:equatable/equatable.dart';

class FlashSale extends Equatable {
  const FlashSale({required this.endsAt, required this.discountPct});
  final String endsAt;
  final int discountPct;

  factory FlashSale.fromJson(Map<String, dynamic> json) => FlashSale(
        endsAt: json['endsAt'] as String,
        discountPct: (json['discountPct'] as num).toInt(),
      );

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

  double get effectivePrice {
    if (flashSale == null) return priceGhs;
    return priceGhs * (1 - flashSale!.discountPct / 100);
  }

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
        if (flashSale != null)
          'flashSale': {
            'endsAt': flashSale!.endsAt,
            'discountPct': flashSale!.discountPct,
          },
        'supports': supports,
      };

  @override
  List<Object?> get props => [id, slug, name, priceGhs, sellerId, stock];
}
