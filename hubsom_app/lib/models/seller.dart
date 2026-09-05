import 'package:equatable/equatable.dart';

class Seller extends Equatable {
  const Seller({
    required this.id,
    required this.slug,
    required this.name,
    required this.city,
    required this.region,
    this.address = '',
    required this.bio,
    required this.avatar,
    required this.cover,
    this.rating = 0,
    this.followers = 0,
    this.verified = false,
    this.categories = const [],
    this.ownerUserId,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String slug;
  final String name;
  final String city;
  final String region;
  /// Street / area shown on the public store (optional).
  final String address;
  final String bio;
  final String avatar;
  final String cover;
  final double rating;
  final int followers;
  final bool verified;
  final List<String> categories;
  final String? ownerUserId;
  final double? latitude;
  final double? longitude;

  factory Seller.fromJson(Map<String, dynamic> json) => Seller(
        id: json['id'] as String,
        slug: json['slug'] as String? ?? json['id'] as String,
        name: json['name'] as String? ?? '',
        city: json['city'] as String? ?? 'Accra',
        region: json['region'] as String? ?? 'Greater Accra',
        address: json['address'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
        avatar: json['avatar'] as String? ?? '',
        cover: json['cover'] as String? ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        followers: (json['followers'] as num?)?.toInt() ?? 0,
        verified: json['verified'] as bool? ?? false,
        categories: (json['categories'] as List?)?.cast<String>() ?? const [],
        ownerUserId: json['ownerUserId'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'city': city,
        'region': region,
        if (address.isNotEmpty) 'address': address,
        'bio': bio,
        'avatar': avatar,
        'cover': cover,
        'rating': rating,
        'followers': followers,
        'verified': verified,
        'categories': categories,
        if (ownerUserId != null) 'ownerUserId': ownerUserId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  Seller copyWith({
    String? name,
    String? city,
    String? region,
    String? address,
    String? bio,
    String? avatar,
    String? cover,
    double? rating,
    int? followers,
    bool? verified,
    List<String>? categories,
    String? ownerUserId,
    double? latitude,
    double? longitude,
  }) =>
      Seller(
        id: id,
        slug: slug,
        name: name ?? this.name,
        city: city ?? this.city,
        region: region ?? this.region,
        address: address ?? this.address,
        bio: bio ?? this.bio,
        avatar: avatar ?? this.avatar,
        cover: cover ?? this.cover,
        rating: rating ?? this.rating,
        followers: followers ?? this.followers,
        verified: verified ?? this.verified,
        categories: categories ?? this.categories,
        ownerUserId: ownerUserId ?? this.ownerUserId,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );

  /// Public location line, e.g. "Osu, Accra, Greater Accra".
  String get displayLocation {
    final parts = <String>[
      if (address.trim().isNotEmpty) address.trim(),
      if (city.trim().isNotEmpty) city.trim(),
      if (region.trim().isNotEmpty) region.trim(),
    ];
    return parts.join(', ');
  }

  @override
  List<Object?> get props => [id, slug, name, followers, verified];
}
