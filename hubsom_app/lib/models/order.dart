import 'package:equatable/equatable.dart';

import 'user.dart';

class OrderLine extends Equatable {
  const OrderLine({
    required this.productId,
    this.sellerId,
    required this.name,
    this.image,
    required this.quantity,
    required this.unitPriceGhs,
    required this.lineTotalGhs,
    required this.category,
  });

  final String productId;
  final String? sellerId;
  final String name;
  final String? image;
  final int quantity;
  final double unitPriceGhs;
  final double lineTotalGhs;
  final String category;

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        productId: json['productId'] as String,
        sellerId: json['sellerId'] as String?,
        name: json['name'] as String? ?? '',
        image: json['image'] as String?,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        unitPriceGhs: (json['unitPriceGhs'] as num?)?.toDouble() ?? 0,
        lineTotalGhs: (json['lineTotalGhs'] as num?)?.toDouble() ?? 0,
        category: json['category'] as String? ?? 'miscellaneous',
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        if (sellerId != null) 'sellerId': sellerId,
        'name': name,
        if (image != null) 'image': image,
        'quantity': quantity,
        'unitPriceGhs': unitPriceGhs,
        'lineTotalGhs': lineTotalGhs,
        'category': category,
      };

  @override
  List<Object?> get props => [productId, quantity, lineTotalGhs];
}

class OrderShipping extends Equatable {
  const OrderShipping({
    required this.recipientName,
    required this.phone,
    required this.line1,
    this.line2,
    required this.city,
    required this.region,
    this.notes,
    this.label,
    this.location,
  });

  final String recipientName;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String region;
  final String? notes;
  final String? label;
  final GeoLocation? location;

  factory OrderShipping.fromJson(Map<String, dynamic> json) => OrderShipping(
        recipientName: json['recipientName'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        line1: json['line1'] as String? ?? '',
        line2: json['line2'] as String?,
        city: json['city'] as String? ?? 'Accra',
        region: json['region'] as String? ?? 'Greater Accra',
        notes: json['notes'] as String?,
        label: json['label'] as String?,
        location: json['location'] != null
            ? GeoLocation.fromJson(Map<String, dynamic>.from(json['location'] as Map))
            : null,
      );

  Map<String, dynamic> toJson() => {
        'recipientName': recipientName,
        'phone': phone,
        'line1': line1,
        if (line2 != null) 'line2': line2,
        'city': city,
        'region': region,
        if (notes != null) 'notes': notes,
        if (label != null) 'label': label,
        if (location != null) 'location': location!.toJson(),
      };

  @override
  List<Object?> get props => [recipientName, phone, line1, city, region, location];
}

class Order extends Equatable {
  const Order({
    required this.id,
    this.currency = 'GHS',
    required this.subtotalGhs,
    required this.status,
    this.userId,
    this.buyerName,
    this.buyerEmail,
    this.streamId,
    this.oneTap = false,
    required this.lines,
    this.shipping,
    this.paymentMethods = const [],
    this.deliveryEstimate = '',
    required this.createdAt,
  });

  final String id;
  final String currency;
  final double subtotalGhs;
  final String status;
  final String? userId;
  final String? buyerName;
  final String? buyerEmail;
  final String? streamId;
  final bool oneTap;
  final List<OrderLine> lines;
  final OrderShipping? shipping;
  final List<String> paymentMethods;
  final String deliveryEstimate;
  final String createdAt;

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        currency: json['currency'] as String? ?? 'GHS',
        subtotalGhs: (json['subtotalGhs'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'pending_payment',
        userId: json['userId'] as String?,
        buyerName: json['buyerName'] as String?,
        buyerEmail: json['buyerEmail'] as String?,
        streamId: json['streamId'] as String?,
        oneTap: json['oneTap'] as bool? ?? false,
        lines: (json['lines'] as List?)
                ?.map((e) => OrderLine.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        shipping: json['shipping'] != null
            ? OrderShipping.fromJson(Map<String, dynamic>.from(json['shipping'] as Map))
            : null,
        paymentMethods: (json['paymentMethods'] as List?)?.cast<String>() ?? const [],
        deliveryEstimate: json['deliveryEstimate'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'currency': currency,
        'subtotalGhs': subtotalGhs,
        'status': status,
        if (userId != null) 'userId': userId,
        if (buyerName != null) 'buyerName': buyerName,
        if (buyerEmail != null) 'buyerEmail': buyerEmail,
        if (streamId != null) 'streamId': streamId,
        'oneTap': oneTap,
        'lines': lines.map((e) => e.toJson()).toList(),
        if (shipping != null) 'shipping': shipping!.toJson(),
        'paymentMethods': paymentMethods,
        'deliveryEstimate': deliveryEstimate,
        'createdAt': createdAt,
      };

  @override
  List<Object?> get props => [id, status, subtotalGhs, lines];

  Order copyWith({
    String? status,
    String? buyerName,
    String? buyerEmail,
    OrderShipping? shipping,
    String? deliveryEstimate,
  }) {
    return Order(
      id: id,
      currency: currency,
      subtotalGhs: subtotalGhs,
      status: status ?? this.status,
      userId: userId,
      buyerName: buyerName ?? this.buyerName,
      buyerEmail: buyerEmail ?? this.buyerEmail,
      streamId: streamId,
      oneTap: oneTap,
      lines: lines,
      shipping: shipping ?? this.shipping,
      paymentMethods: paymentMethods,
      deliveryEstimate: deliveryEstimate ?? this.deliveryEstimate,
      createdAt: createdAt,
    );
  }
}
