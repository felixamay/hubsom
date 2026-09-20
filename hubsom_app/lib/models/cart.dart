import 'package:equatable/equatable.dart';

class CartItem extends Equatable {
  const CartItem({
    required this.productId,
    required this.quantity,
    required this.source,
    this.streamId,
    this.liveQuantity = 0,
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
  /// Units on this line that came from a live bag. Shop / flash adds must
  /// not raise this, or checkout would consume the whole merged qty live.
  final int liveQuantity;
  final String name;
  final double priceGhs;
  final double shipmentFeeGhs;
  final String? image;
  final String? category;

  int get liveConsumeQty {
    if (streamId == null || streamId!.trim().isEmpty) return 0;
    return liveQuantity < 0 ? 0 : liveQuantity;
  }

  double get lineTotal => priceGhs * quantity;
  double get shipmentLineTotal => shipmentFeeGhs * quantity;
  double get payableTotal => lineTotal + shipmentLineTotal;

  CartItem copyWith({
    int? quantity,
    String? source,
    String? streamId,
    int? liveQuantity,
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
        liveQuantity: liveQuantity ?? this.liveQuantity,
        name: name ?? this.name,
        priceGhs: priceGhs ?? this.priceGhs,
        shipmentFeeGhs: shipmentFeeGhs ?? this.shipmentFeeGhs,
        image: image ?? this.image,
        category: category ?? this.category,
      );

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final streamId = json['streamId'] as String?;
    final quantity = (json['quantity'] as num?)?.toInt() ?? 1;
    // Older carts had no liveQuantity. If the line still points at a show,
    // treat the whole qty as live so we do not under-consume those bags.
    final parsedLive = json.containsKey('liveQuantity')
        ? (json['liveQuantity'] as num?)?.toInt() ?? 0
        : ((streamId != null && streamId.trim().isNotEmpty) ? quantity : 0);
    return CartItem(
      productId: json['productId'] as String,
      quantity: quantity,
      source: json['source'] as String? ?? 'buy-now',
      streamId: streamId,
      liveQuantity: parsedLive,
      name: json['name'] as String? ?? '',
      priceGhs: (json['priceGhs'] as num?)?.toDouble() ?? 0,
      shipmentFeeGhs: (json['shipmentFeeGhs'] as num?)?.toDouble() ?? 0,
      image: json['image'] as String?,
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'source': source,
        if (streamId != null) 'streamId': streamId,
        'liveQuantity': liveQuantity,
        'name': name,
        'priceGhs': priceGhs,
        if (shipmentFeeGhs > 0) 'shipmentFeeGhs': shipmentFeeGhs,
        if (image != null) 'image': image,
        if (category != null) 'category': category,
      };

  @override
  List<Object?> get props =>
      [productId, quantity, source, streamId, liveQuantity, priceGhs, shipmentFeeGhs];
}
