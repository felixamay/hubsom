import 'package:equatable/equatable.dart';

class Seller extends Equatable {
  const Seller({
    required this.id,
    required this.slug,
    required this.name,
    required this.city,
    required this.region,
    required this.bio,
    required this.avatar,
    required this.cover,
    this.rating = 0,
    this.followers = 0,
    this.verified = false,
    this.categories = const [],
    this.ownerUserId,
  });

  final String id;
  final String slug;
  final String name;
  final String city;
  final String region;
  final String bio;
  final String avatar;
  final String cover;
  final double rating;
  final int followers;
  final bool verified;
  final List<String> categories;
  final String? ownerUserId;

  factory Seller.fromJson(Map<String, dynamic> json) => Seller(
        id: json['id'] as String,
        slug: json['slug'] as String? ?? json['id'] as String,
        name: json['name'] as String? ?? '',
        city: json['city'] as String? ?? 'Accra',
        region: json['region'] as String? ?? 'Greater Accra',
        bio: json['bio'] as String? ?? '',
        avatar: json['avatar'] as String? ?? '',
        cover: json['cover'] as String? ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        followers: (json['followers'] as num?)?.toInt() ?? 0,
        verified: json['verified'] as bool? ?? false,
        categories: (json['categories'] as List?)?.cast<String>() ?? const [],
        ownerUserId: json['ownerUserId'] as String?,
      );

  @override
  List<Object?> get props => [id, slug, name, followers, verified];
}
