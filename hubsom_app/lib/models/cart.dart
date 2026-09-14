import 'package:equatable/equatable.dart';

class CartItem extends Equatable {
  const CartItem({
    required this.productId,
    required this.quantity,
    required this.source,
    this.streamId,
    required this.name,
    required this.priceGhs,
    this.shipmentFeeGhs = 0,
    this.image,
    this.category,
  });

  final String productId;
  final int quantity;
  final String source; // buy-now | live | auction | flash-sale | bundle
  final String? streamId;
  final String name;
  final double priceGhs;
  final double shipmentFeeGhs;
  final String? image;
  final String? category;

  double get lineTotal => priceGhs * quantity;
  double get shipmentLineTotal => shipmentFeeGhs * quantity;
  double get payableTotal => lineTotal + shipmentLineTotal;

  CartItem copyWith({
    int? quantity,
    String? source,
    String? streamId,
    String? name,
    double? priceGhs,
    double? shipmentFeeGhs,
    String? image,
    String? category,
  }) =>
      CartItem(
        productId: productId,
        quantity: quantity ?? this.quantity,
        source: source ?? this.source,
        streamId: streamId ?? this.streamId,
        name: name ?? this.name,
        priceGhs: priceGhs ?? this.priceGhs,
        shipmentFeeGhs: shipmentFeeGhs ?? this.shipmentFeeGhs,
        image: image ?? this.image,
        category: category ?? this.category,
      );

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        productId: json['productId'] as String,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        source: json['source'] as String? ?? 'buy-now',
        streamId: json['streamId'] as String?,
        name: json['name'] as String? ?? '',
        priceGhs: (json['priceGhs'] as num?)?.toDouble() ?? 0,
        shipmentFeeGhs: (json['shipmentFeeGhs'] as num?)?.toDouble() ?? 0,
        image: json['image'] as String?,
        category: json['category'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'source': source,
        if (streamId != null) 'streamId': streamId,
        'name': name,
        'priceGhs': priceGhs,
        if (shipmentFeeGhs > 0) 'shipmentFeeGhs': shipmentFeeGhs,
        if (image != null) 'image': image,
        if (category != null) 'category': category,
      };

  @override
  List<Object?> get props =>
      [productId, quantity, source, priceGhs, shipmentFeeGhs];
}
