import 'package:equatable/equatable.dart';

import 'user.dart';

/// Vehicle categories ported from the Huber Android driver app.
abstract final class HuberVehicleType {
  static const motorcycle = 'motorcycle';
  static const car = 'car';
  static const van = 'van';
  static const pickupTruck = 'pickup_truck';
  static const bicycle = 'bicycle';
  static const walkingCourier = 'walking_courier';

  static const values = <String>[
    motorcycle,
    car,
    van,
    pickupTruck,
    bicycle,
    walkingCourier,
  ];

  static String label(String value) => switch (value) {
        motorcycle => 'Motorcycle',
        car => 'Car',
        van => 'Van',
        pickupTruck => 'Pickup truck',
        bicycle => 'Bicycle',
        walkingCourier => 'Walking courier',
        _ => value,
      };
}

class HuberSignUpDetails {
  const HuberSignUpDetails({
    required this.phone,
    this.city = 'Accra',
    this.region = 'Greater Accra',
    this.vehicleType = HuberVehicleType.motorcycle,
    this.vehiclePlate = '',
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  final String phone;
  final String city;
  final String region;
  final String vehicleType;
  final String vehiclePlate;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
}

class HuberProfile extends Equatable {
  const HuberProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    this.city = 'Accra',
    this.region = 'Greater Accra',
    this.vehicleType = HuberVehicleType.motorcycle,
    this.vehiclePlate,
    this.verificationStatus = 'pending',
    this.availability = 'offline',
    this.rating = 0,
    this.acceptanceRate = 0,
    this.completedCount = 0,
    this.declinedCount = 0,
    this.walletBalanceGhs = 0,
    this.todayEarningsGhs = 0,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.idType,
    this.idNumber,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String city;
  final String region;
  final String vehicleType;
  final String? vehiclePlate;
  final String verificationStatus; // pending | approved | rejected
  final String availability; // offline | available | busy
  final double rating;
  final double acceptanceRate;
  final int completedCount;
  final int declinedCount;
  final double walletBalanceGhs;
  final double todayEarningsGhs;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? idType;
  final String? idNumber;
  /// Last GPS pin the rider shared (Hub Now / delivery).
  final double? latitude;
  final double? longitude;
  final String createdAt;
  final String updatedAt;

  bool get isVerified => verificationStatus == 'approved';
  bool get isOnline => availability == 'available' || availability == 'busy';

  factory HuberProfile.fromUser(
    HubsomUser user, {
    required HuberSignUpDetails details,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return HuberProfile(
      id: user.huberId ?? 'huber-${user.id}',
      userId: user.id,
      fullName: user.name,
      email: user.email,
      phone: details.phone,
      city: details.city,
      region: details.region,
      vehicleType: details.vehicleType,
      vehiclePlate: details.vehiclePlate.isEmpty ? null : details.vehiclePlate,
      emergencyContactName: details.emergencyContactName,
      emergencyContactPhone: details.emergencyContactPhone,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory HuberProfile.fromJson(Map<String, dynamic> json) => HuberProfile(
        id: json['id'] as String,
        userId: json['userId'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        city: json['city'] as String? ?? 'Accra',
        region: json['region'] as String? ?? 'Greater Accra',
        vehicleType: json['vehicleType'] as String? ?? HuberVehicleType.motorcycle,
        vehiclePlate: json['vehiclePlate'] as String?,
        verificationStatus: json['verificationStatus'] as String? ?? 'pending',
        availability: json['availability'] as String? ?? 'offline',
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        acceptanceRate: (json['acceptanceRate'] as num?)?.toDouble() ?? 0,
        completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
        declinedCount: (json['declinedCount'] as num?)?.toInt() ?? 0,
        walletBalanceGhs: (json['walletBalanceGhs'] as num?)?.toDouble() ?? 0,
        todayEarningsGhs: (json['todayEarningsGhs'] as num?)?.toDouble() ?? 0,
        emergencyContactName: json['emergencyContactName'] as String?,
        emergencyContactPhone: json['emergencyContactPhone'] as String?,
        idType: json['idType'] as String?,
        idNumber: json['idNumber'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        createdAt: json['createdAt'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
      );

  HuberProfile copyWith({
    String? phone,
    String? city,
    String? vehicleType,
    String? vehiclePlate,
    String? verificationStatus,
    String? availability,
    double? rating,
    double? acceptanceRate,
    int? completedCount,
    int? declinedCount,
    double? walletBalanceGhs,
    double? todayEarningsGhs,
    String? idType,
    String? idNumber,
    double? latitude,
    double? longitude,
    String? updatedAt,
  }) =>
      HuberProfile(
        id: id,
        userId: userId,
        fullName: fullName,
        email: email,
        phone: phone ?? this.phone,
        city: city ?? this.city,
        region: region,
        vehicleType: vehicleType ?? this.vehicleType,
        vehiclePlate: vehiclePlate ?? this.vehiclePlate,
        verificationStatus: verificationStatus ?? this.verificationStatus,
        availability: availability ?? this.availability,
        rating: rating ?? this.rating,
        acceptanceRate: acceptanceRate ?? this.acceptanceRate,
        completedCount: completedCount ?? this.completedCount,
        declinedCount: declinedCount ?? this.declinedCount,
        walletBalanceGhs: walletBalanceGhs ?? this.walletBalanceGhs,
        todayEarningsGhs: todayEarningsGhs ?? this.todayEarningsGhs,
        emergencyContactName: emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
        idType: idType ?? this.idType,
        idNumber: idNumber ?? this.idNumber,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'city': city,
        'region': region,
        'vehicleType': vehicleType,
        if (vehiclePlate != null) 'vehiclePlate': vehiclePlate,
        'verificationStatus': verificationStatus,
        'availability': availability,
        'rating': rating,
        'acceptanceRate': acceptanceRate,
        'completedCount': completedCount,
        'declinedCount': declinedCount,
        'walletBalanceGhs': walletBalanceGhs,
        'todayEarningsGhs': todayEarningsGhs,
        if (emergencyContactName != null)
          'emergencyContactName': emergencyContactName,
        if (emergencyContactPhone != null)
          'emergencyContactPhone': emergencyContactPhone,
        if (idType != null) 'idType': idType,
        if (idNumber != null) 'idNumber': idNumber,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  @override
  List<Object?> get props => [id, userId, availability, verificationStatus];
}

/// Driver-facing offer (Hubsom DeliveryOffer + pickup/dropoff snapshot).
class HuberOffer extends Equatable {
  const HuberOffer({
    required this.id,
    required this.shipmentId,
    required this.huberId,
    required this.huberName,
    required this.status,
    this.offeredFeeGhs,
    this.providerReference,
    required this.createdAt,
    required this.expiresAt,
    this.sellerName = 'Hubsom seller',
    this.pickupLabel = 'Seller pickup',
    this.pickupCity = 'Accra',
    this.recipientName = '',
    this.dropoffLine1 = '',
    this.dropoffCity = 'Accra',
    this.itemCount = 1,
    this.weightLbs = 8,
    this.source = 'hubsom',
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.pickupDistanceKm,
  });

  final String id;
  final String shipmentId;
  final String huberId;
  final String huberName;
  final String status;
  final double? offeredFeeGhs;
  final String? providerReference;
  final String createdAt;
  final String expiresAt;
  final String sellerName;
  final String pickupLabel;
  final String pickupCity;
  final String recipientName;
  final String dropoffLine1;
  final String dropoffCity;
  final int itemCount;
  final double weightLbs;
  final String source;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  /// Straight-line km from the rider's city to the seller pickup.
  final double? pickupDistanceKm;

  bool get isOpen => status == 'sent' || status == 'queued';

  String get pickupDistanceLabel {
    final km = pickupDistanceKm;
    if (km == null) return '';
    if (km < 0.1) return 'Under 100 m to pickup';
    if (km < 1) return '${(km * 1000).round()} m to pickup';
    if (km < 10) return '${km.toStringAsFixed(1)} km to pickup';
    return '${km.round()} km to pickup';
  }

  bool get isExpired {
    if (!isOpen) return false;
    final exp = DateTime.tryParse(expiresAt);
    return exp != null && DateTime.now().toUtc().isAfter(exp.toUtc());
  }

  int get secondsRemaining {
    final exp = DateTime.tryParse(expiresAt);
    if (exp == null) return 0;
    return exp.toUtc().difference(DateTime.now().toUtc()).inSeconds.clamp(0, 9999);
  }

  factory HuberOffer.fromJson(Map<String, dynamic> json) => HuberOffer(
        id: json['id'] as String,
        shipmentId: json['shipmentId'] as String? ?? '',
        huberId: json['huberId'] as String? ?? '',
        huberName: json['huberName'] as String? ?? '',
        status: json['status'] as String? ?? 'queued',
        offeredFeeGhs: (json['offeredFeeGhs'] as num?)?.toDouble(),
        providerReference: json['providerReference'] as String?,
        createdAt: json['createdAt'] as String? ?? '',
        expiresAt: json['expiresAt'] as String? ?? '',
        sellerName: json['sellerName'] as String? ?? 'Hubsom seller',
        pickupLabel: json['pickupLabel'] as String? ?? 'Seller pickup',
        pickupCity: json['pickupCity'] as String? ?? 'Accra',
        recipientName: json['recipientName'] as String? ?? '',
        dropoffLine1: json['dropoffLine1'] as String? ?? '',
        dropoffCity: json['dropoffCity'] as String? ?? 'Accra',
        itemCount: (json['itemCount'] as num?)?.toInt() ?? 1,
        weightLbs: (json['weightLbs'] as num?)?.toDouble() ?? 8,
        source: json['source'] as String? ?? 'hubsom',
        pickupLatitude: (json['pickupLatitude'] as num?)?.toDouble(),
        pickupLongitude: (json['pickupLongitude'] as num?)?.toDouble(),
        dropoffLatitude: (json['dropoffLatitude'] as num?)?.toDouble(),
        dropoffLongitude: (json['dropoffLongitude'] as num?)?.toDouble(),
        pickupDistanceKm: (json['pickupDistanceKm'] as num?)?.toDouble(),
      );

  HuberOffer copyWith({String? status}) => HuberOffer(
        id: id,
        shipmentId: shipmentId,
        huberId: huberId,
        huberName: huberName,
        status: status ?? this.status,
        offeredFeeGhs: offeredFeeGhs,
        providerReference: providerReference,
        createdAt: createdAt,
        expiresAt: expiresAt,
        sellerName: sellerName,
        pickupLabel: pickupLabel,
        pickupCity: pickupCity,
        recipientName: recipientName,
        dropoffLine1: dropoffLine1,
        dropoffCity: dropoffCity,
        itemCount: itemCount,
        weightLbs: weightLbs,
        source: source,
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        dropoffLatitude: dropoffLatitude,
        dropoffLongitude: dropoffLongitude,
        pickupDistanceKm: pickupDistanceKm,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'shipmentId': shipmentId,
        'huberId': huberId,
        'huberName': huberName,
        'status': status,
        if (offeredFeeGhs != null) 'offeredFeeGhs': offeredFeeGhs,
        if (providerReference != null) 'providerReference': providerReference,
        'createdAt': createdAt,
        'expiresAt': expiresAt,
        'sellerName': sellerName,
        'pickupLabel': pickupLabel,
        'pickupCity': pickupCity,
        'recipientName': recipientName,
        'dropoffLine1': dropoffLine1,
        'dropoffCity': dropoffCity,
        'itemCount': itemCount,
        'weightLbs': weightLbs,
        'source': source,
        if (pickupLatitude != null) 'pickupLatitude': pickupLatitude,
        if (pickupLongitude != null) 'pickupLongitude': pickupLongitude,
        if (dropoffLatitude != null) 'dropoffLatitude': dropoffLatitude,
        if (dropoffLongitude != null) 'dropoffLongitude': dropoffLongitude,
        if (pickupDistanceKm != null) 'pickupDistanceKm': pickupDistanceKm,
      };

  @override
  List<Object?> get props => [id, huberId, status, shipmentId];
}

class HuberDelivery extends Equatable {
  const HuberDelivery({
    required this.id,
    required this.offerId,
    required this.shipmentId,
    required this.huberId,
    required this.status,
    required this.sellerName,
    required this.pickupAddress,
    required this.customerName,
    required this.dropoffAddress,
    required this.feeGhs,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String offerId;
  final String shipmentId;
  final String huberId;
  final String status;
  final String sellerName;
  final String pickupAddress;
  final String customerName;
  final String dropoffAddress;
  final double feeGhs;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final String createdAt;
  final String updatedAt;

  bool get isActive =>
      status != 'delivered' && status != 'cancelled';

  String get stepLabel => switch (status) {
        'accepted' || 'en_route_pickup' => 'Navigate to pickup',
        'arrived_pickup' => 'Confirm pickup',
        'picked_up' || 'en_route_dropoff' => 'Deliver to customer',
        'arrived_dropoff' => 'Proof of delivery',
        'delivered' => 'Delivered',
        _ => status.replaceAll('_', ' '),
      };

  factory HuberDelivery.fromJson(Map<String, dynamic> json) => HuberDelivery(
        id: json['id'] as String,
        offerId: json['offerId'] as String? ?? '',
        shipmentId: json['shipmentId'] as String? ?? '',
        huberId: json['huberId'] as String? ?? '',
        status: json['status'] as String? ?? 'accepted',
        sellerName: json['sellerName'] as String? ?? 'Hubsom seller',
        pickupAddress: json['pickupAddress'] as String? ?? '',
        customerName: json['customerName'] as String? ?? '',
        dropoffAddress: json['dropoffAddress'] as String? ?? '',
        feeGhs: (json['feeGhs'] as num?)?.toDouble() ?? 0,
        pickupLatitude: (json['pickupLatitude'] as num?)?.toDouble(),
        pickupLongitude: (json['pickupLongitude'] as num?)?.toDouble(),
        dropoffLatitude: (json['dropoffLatitude'] as num?)?.toDouble(),
        dropoffLongitude: (json['dropoffLongitude'] as num?)?.toDouble(),
        createdAt: json['createdAt'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
      );

  HuberDelivery copyWith({String? status, String? updatedAt}) => HuberDelivery(
        id: id,
        offerId: offerId,
        shipmentId: shipmentId,
        huberId: huberId,
        status: status ?? this.status,
        sellerName: sellerName,
        pickupAddress: pickupAddress,
        customerName: customerName,
        dropoffAddress: dropoffAddress,
        feeGhs: feeGhs,
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        dropoffLatitude: dropoffLatitude,
        dropoffLongitude: dropoffLongitude,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'offerId': offerId,
        'shipmentId': shipmentId,
        'huberId': huberId,
        'status': status,
        'sellerName': sellerName,
        'pickupAddress': pickupAddress,
        'customerName': customerName,
        'dropoffAddress': dropoffAddress,
        'feeGhs': feeGhs,
        if (pickupLatitude != null) 'pickupLatitude': pickupLatitude,
        if (pickupLongitude != null) 'pickupLongitude': pickupLongitude,
        if (dropoffLatitude != null) 'dropoffLatitude': dropoffLatitude,
        if (dropoffLongitude != null) 'dropoffLongitude': dropoffLongitude,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  @override
  List<Object?> get props => [id, status, shipmentId];
}
