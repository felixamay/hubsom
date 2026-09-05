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
    this.huberId,
    this.followingSellerIds = const [],
    this.savedProductIds = const [],
    this.likedProductIds = const [],
    this.savedVideoIds = const [],
    this.likedVideoIds = const [],
    this.addresses = const [],
    this.emailVerified = false,
    this.walletBalanceGhs = 0,
    this.giftPoints = 0,
    this.giftEarningsGhs = 0,
  });

  final String id;
  final String email;
  final String name;
  final String? image;
  final String? phone;
  final String? city;
  final String? region;
  final String? bio;
  final String role; // buyer | seller | both | huber | admin
  final String? sellerId;
  final String? huberId;
  final List<String> followingSellerIds;
  final List<String> savedProductIds;
  final List<String> likedProductIds;
  final List<String> savedVideoIds;
  final List<String> likedVideoIds;
  final List<UserAddress> addresses;
  final bool emailVerified;
  final double walletBalanceGhs;
  /// Spendable live-gift coins purchased by the viewer.
  final int giftPoints;
  /// Host earnings from gifts received on live shows.
  final double giftEarningsGhs;

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
        huberId: json['huberId'] as String?,
        followingSellerIds: (json['followingSellerIds'] as List?)?.cast<String>() ?? const [],
        savedProductIds: (json['savedProductIds'] as List?)?.cast<String>() ?? const [],
        likedProductIds: (json['likedProductIds'] as List?)?.cast<String>() ?? const [],
        savedVideoIds: (json['savedVideoIds'] as List?)?.cast<String>() ?? const [],
        likedVideoIds: (json['likedVideoIds'] as List?)?.cast<String>() ?? const [],
        addresses: (json['addresses'] as List?)
                ?.map((e) => UserAddress.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        emailVerified: json['emailVerified'] as bool? ?? false,
        walletBalanceGhs: (json['walletBalanceGhs'] as num?)?.toDouble() ?? 0,
        giftPoints: (json['giftPoints'] as num?)?.toInt() ?? 0,
        giftEarningsGhs: (json['giftEarningsGhs'] as num?)?.toDouble() ?? 0,
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
        if (huberId != null) 'huberId': huberId,
        'followingSellerIds': followingSellerIds,
        'savedProductIds': savedProductIds,
        'likedProductIds': likedProductIds,
        'savedVideoIds': savedVideoIds,
        'likedVideoIds': likedVideoIds,
        'addresses': addresses.map((a) => a.toJson()).toList(),
        'emailVerified': emailVerified,
        'walletBalanceGhs': walletBalanceGhs,
        'giftPoints': giftPoints,
        'giftEarningsGhs': giftEarningsGhs,
      };

  HubsomUser copyWith({
    String? name,
    String? image,
    String? phone,
    String? city,
    String? region,
    String? bio,
    String? role,
    String? sellerId,
    String? huberId,
    List<String>? followingSellerIds,
    List<String>? savedProductIds,
    List<String>? likedProductIds,
    List<String>? savedVideoIds,
    List<String>? likedVideoIds,
    List<UserAddress>? addresses,
    bool? emailVerified,
    double? walletBalanceGhs,
    int? giftPoints,
    double? giftEarningsGhs,
  }) =>
      HubsomUser(
        id: id,
        email: email,
        name: name ?? this.name,
        image: image ?? this.image,
        phone: phone ?? this.phone,
        city: city ?? this.city,
        region: region ?? this.region,
        bio: bio ?? this.bio,
        role: role ?? this.role,
        sellerId: sellerId ?? this.sellerId,
        huberId: huberId ?? this.huberId,
        followingSellerIds: followingSellerIds ?? this.followingSellerIds,
        savedProductIds: savedProductIds ?? this.savedProductIds,
        likedProductIds: likedProductIds ?? this.likedProductIds,
        savedVideoIds: savedVideoIds ?? this.savedVideoIds,
        likedVideoIds: likedVideoIds ?? this.likedVideoIds,
        addresses: addresses ?? this.addresses,
        emailVerified: emailVerified ?? this.emailVerified,
        walletBalanceGhs: walletBalanceGhs ?? this.walletBalanceGhs,
        giftPoints: giftPoints ?? this.giftPoints,
        giftEarningsGhs: giftEarningsGhs ?? this.giftEarningsGhs,
      );

  bool get isHuber =>
      role == 'huber' ||
      role == 'driver' ||
      (huberId != null && huberId!.isNotEmpty);

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        role,
        sellerId,
        huberId,
        savedProductIds,
        likedProductIds,
        savedVideoIds,
        likedVideoIds,
        walletBalanceGhs,
        giftPoints,
        giftEarningsGhs,
      ];
}
