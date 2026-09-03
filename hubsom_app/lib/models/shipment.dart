import 'package:equatable/equatable.dart';

import 'order.dart';

class ShipmentItem extends Equatable {
  const ShipmentItem({
    required this.orderId,
    required this.productId,
    required this.name,
    required this.quantity,
    this.image,
    required this.lineTotalGhs,
  });

  final String orderId;
  final String productId;
  final String name;
  final int quantity;
  final String? image;
  final double lineTotalGhs;

  factory ShipmentItem.fromJson(Map<String, dynamic> json) => ShipmentItem(
        orderId: json['orderId'] as String? ?? '',
        productId: json['productId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        image: json['image'] as String?,
        lineTotalGhs: (json['lineTotalGhs'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'productId': productId,
        'name': name,
        'quantity': quantity,
        if (image != null) 'image': image,
        'lineTotalGhs': lineTotalGhs,
      };

  @override
  List<Object?> get props => [orderId, productId, quantity];
}

class DeliveryOffer extends Equatable {
  const DeliveryOffer({
    required this.id,
    required this.shipmentId,
    required this.huberId,
    required this.huberName,
    required this.status,
    this.offeredFeeGhs,
    this.providerReference,
    required this.createdAt,
    required this.expiresAt,
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

  factory DeliveryOffer.fromJson(Map<String, dynamic> json) => DeliveryOffer(
        id: json['id'] as String,
        shipmentId: json['shipmentId'] as String? ?? '',
        huberId: json['huberId'] as String? ?? '',
        huberName: json['huberName'] as String? ?? '',
        status: json['status'] as String? ?? 'queued',
        offeredFeeGhs: (json['offeredFeeGhs'] as num?)?.toDouble(),
        providerReference: json['providerReference'] as String?,
        createdAt: json['createdAt'] as String? ?? '',
        expiresAt: json['expiresAt'] as String? ?? '',
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
      };

  @override
  List<Object?> get props => [id, huberId, status];
}

class Shipment extends Equatable {
  const Shipment({
    required this.id,
    required this.sellerId,
    required this.createdByUserId,
    required this.orderIds,
    required this.items,
    required this.destination,
    required this.status,
    this.assignedHuberId,
    this.assignedHuberName,
    this.offers = const [],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String sellerId;
  final String createdByUserId;
  final List<String> orderIds;
  final List<ShipmentItem> items;
  final OrderShipping destination;
  final String status;
  final String? assignedHuberId;
  final String? assignedHuberName;
  final List<DeliveryOffer> offers;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  factory Shipment.fromJson(Map<String, dynamic> json) => Shipment(
        id: json['id'] as String,
        sellerId: json['sellerId'] as String? ?? '',
        createdByUserId: json['createdByUserId'] as String? ?? '',
        orderIds: (json['orderIds'] as List?)?.cast<String>() ?? const [],
        items: (json['items'] as List?)
                ?.map((e) => ShipmentItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        destination: OrderShipping.fromJson(
          Map<String, dynamic>.from(json['destination'] as Map? ?? {}),
        ),
        status: json['status'] as String? ?? 'draft',
        assignedHuberId: json['assignedHuberId'] as String?,
        assignedHuberName: json['assignedHuberName'] as String?,
        offers: (json['offers'] as List?)
                ?.map((e) => DeliveryOffer.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        notes: json['notes'] as String?,
        createdAt: json['createdAt'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
      );

  Shipment copyWith({
    String? status,
    String? assignedHuberId,
    String? assignedHuberName,
    List<DeliveryOffer>? offers,
    String? updatedAt,
  }) =>
      Shipment(
        id: id,
        sellerId: sellerId,
        createdByUserId: createdByUserId,
        orderIds: orderIds,
        items: items,
        destination: destination,
        status: status ?? this.status,
        assignedHuberId: assignedHuberId ?? this.assignedHuberId,
        assignedHuberName: assignedHuberName ?? this.assignedHuberName,
        offers: offers ?? this.offers,
        notes: notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sellerId': sellerId,
        'createdByUserId': createdByUserId,
        'orderIds': orderIds,
        'items': items.map((e) => e.toJson()).toList(),
        'destination': destination.toJson(),
        'status': status,
        if (assignedHuberId != null) 'assignedHuberId': assignedHuberId,
        if (assignedHuberName != null) 'assignedHuberName': assignedHuberName,
        'offers': offers.map((e) => e.toJson()).toList(),
        if (notes != null) 'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  @override
  List<Object?> get props => [id, sellerId, status, assignedHuberId];
}
