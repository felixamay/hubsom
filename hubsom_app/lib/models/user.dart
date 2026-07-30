import 'package:equatable/equatable.dart';

class GeoLocation extends Equatable {
  const GeoLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    this.source,
    this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double? accuracyM;
  final String? source;
  final String? capturedAt;

  factory GeoLocation.fromJson(Map<String, dynamic> json) => GeoLocation(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracyM: (json['accuracyM'] as num?)?.toDouble(),
        source: json['source'] as String?,
        capturedAt: json['capturedAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracyM != null) 'accuracyM': accuracyM,
        if (source != null) 'source': source,
        if (capturedAt != null) 'capturedAt': capturedAt,
      };

  @override
  List<Object?> get props => [latitude, longitude, accuracyM, source, capturedAt];
}

class UserAddress extends Equatable {
  const UserAddress({
    required this.id,
    required this.label,
    required this.line1,
    this.line2,
    required this.city,
    required this.region,
    this.phone,
    this.isDefault,
    this.location,
  });

  final String id;
  final String label;
  final String line1;
  final String? line2;
  final String city;
  final String region;
  final String? phone;
  final bool? isDefault;
  final GeoLocation? location;

  factory UserAddress.fromJson(Map<String, dynamic> json) => UserAddress(
        id: json['id'] as String,
        label: json['label'] as String? ?? 'Home',
        line1: json['line1'] as String? ?? '',
        line2: json['line2'] as String?,
        city: json['city'] as String? ?? 'Accra',
        region: json['region'] as String? ?? 'Greater Accra',
        phone: json['phone'] as String?,
        isDefault: json['isDefault'] as bool?,
        location: json['location'] != null
            ? GeoLocation.fromJson(Map<String, dynamic>.from(json['location'] as Map))
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'line1': line1,
        if (line2 != null) 'line2': line2,
        'city': city,
        'region': region,
        if (phone != null) 'phone': phone,
        if (isDefault != null) 'isDefault': isDefault,
        if (location != null) 'location': location!.toJson(),
      };

  @override
  List<Object?> get props => [id, label, line1, line2, city, region, phone, isDefault, location];
}

class HubsomUser extends Equatable {
  const HubsomUser({
    required this.id,
    required this.email,
    required this.name,
    this.image,
    this.phone,
    this.city,
    this.region,
    this.bio,
    required this.role,
    this.sellerId,
    this.followingSellerIds = const [],
    this.savedProductIds = const [],
    this.addresses = const [],
    this.emailVerified = false,
    this.walletBalanceGhs = 0,
  });

  final String id;
  final String email;
  final String name;
  final String? image;
  final String? phone;
  final String? city;
  final String? region;
  final String? bio;
  final String role; // buyer | seller | both
  final String? sellerId;
  final List<String> followingSellerIds;
  final List<String> savedProductIds;
  final List<UserAddress> addresses;
  final bool emailVerified;
  final double walletBalanceGhs;

  factory HubsomUser.fromJson(Map<String, dynamic> json) => HubsomUser(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        name: json['name'] as String? ?? 'Hubsom user',
        image: json['image'] as String?,
        phone: json['phone'] as String?,
        city: json['city'] as String?,
        region: json['region'] as String?,
        bio: json['bio'] as String?,
        role: json['role'] as String? ?? 'buyer',
        sellerId: json['sellerId'] as String?,
        followingSellerIds: (json['followingSellerIds'] as List?)?.cast<String>() ?? const [],
        savedProductIds: (json['savedProductIds'] as List?)?.cast<String>() ?? const [],
        addresses: (json['addresses'] as List?)
                ?.map((e) => UserAddress.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        emailVerified: json['emailVerified'] as bool? ?? false,
        walletBalanceGhs: (json['walletBalanceGhs'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        if (image != null) 'image': image,
        if (phone != null) 'phone': phone,
        if (city != null) 'city': city,
        if (region != null) 'region': region,
        if (bio != null) 'bio': bio,
        'role': role,
        if (sellerId != null) 'sellerId': sellerId,
        'followingSellerIds': followingSellerIds,
        'savedProductIds': savedProductIds,
        'addresses': addresses.map((a) => a.toJson()).toList(),
        'emailVerified': emailVerified,
        'walletBalanceGhs': walletBalanceGhs,
      };

  @override
  List<Object?> get props => [id, email, name, role, sellerId, savedProductIds, walletBalanceGhs];
}
