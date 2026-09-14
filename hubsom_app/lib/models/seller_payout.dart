import 'package:equatable/equatable.dart';

import '../core/constants/hubsom_commission.dart';

class SellerPayout extends Equatable {
  const SellerPayout({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.orderId,
    required this.salesGhs,
    required this.commissionGhs,
    required this.netGhs,
    required this.status,
    required this.createdAt,
    this.sellerUserId,
    this.sellerEmail = '',
    this.paidAt,
    this.note = '',
  });

  final String id;
  /// Store / seller listing id from the order line.
  final String sellerId;
  final String? sellerUserId;
  final String sellerEmail;
  final String sellerName;
  final String orderId;
  final double salesGhs;
  final double commissionGhs;
  final double netGhs;
  /// pending | paid
  final String status;
  final String createdAt;
  final String? paidAt;
  final String note;

  bool get isPending => status == 'pending';
  bool get isPaid => status == 'paid';

  factory SellerPayout.fromSale({
    required String id,
    required String sellerId,
    required String sellerName,
    required String orderId,
    required double salesGhs,
    String? sellerUserId,
    String sellerEmail = '',
    String createdAt = '',
  }) {
    final sales = HubsomCommission.roundGhs(salesGhs);
    return SellerPayout(
      id: id,
      sellerId: sellerId,
      sellerUserId: sellerUserId,
      sellerEmail: sellerEmail,
      sellerName: sellerName,
      orderId: orderId,
      salesGhs: sales,
      commissionGhs: HubsomCommission.commissionOn(sales),
      netGhs: HubsomCommission.netOn(sales),
      status: 'pending',
      createdAt: createdAt,
    );
  }

  factory SellerPayout.fromJson(Map<String, dynamic> json) => SellerPayout(
        id: '${json['id'] ?? ''}',
        sellerId: '${json['sellerId'] ?? ''}',
        sellerUserId: json['sellerUserId'] as String?,
        sellerEmail: '${json['sellerEmail'] ?? ''}',
        sellerName: '${json['sellerName'] ?? 'Seller'}',
        orderId: '${json['orderId'] ?? ''}',
        salesGhs: (json['salesGhs'] as num?)?.toDouble() ?? 0,
        commissionGhs: (json['commissionGhs'] as num?)?.toDouble() ?? 0,
        netGhs: (json['netGhs'] as num?)?.toDouble() ?? 0,
        status: '${json['status'] ?? 'pending'}',
        createdAt: '${json['createdAt'] ?? ''}',
        paidAt: json['paidAt'] as String?,
        note: '${json['note'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sellerId': sellerId,
        if (sellerUserId != null) 'sellerUserId': sellerUserId,
        'sellerEmail': sellerEmail,
        'sellerName': sellerName,
        'orderId': orderId,
        'salesGhs': salesGhs,
        'commissionGhs': commissionGhs,
        'netGhs': netGhs,
        'status': status,
        'createdAt': createdAt,
        if (paidAt != null) 'paidAt': paidAt,
        if (note.isNotEmpty) 'note': note,
      };

  SellerPayout copyWith({
    String? status,
    String? paidAt,
    String? note,
    String? sellerUserId,
    String? sellerEmail,
    String? sellerName,
  }) =>
      SellerPayout(
        id: id,
        sellerId: sellerId,
        sellerUserId: sellerUserId ?? this.sellerUserId,
        sellerEmail: sellerEmail ?? this.sellerEmail,
        sellerName: sellerName ?? this.sellerName,
        orderId: orderId,
        salesGhs: salesGhs,
        commissionGhs: commissionGhs,
        netGhs: netGhs,
        status: status ?? this.status,
        createdAt: createdAt,
        paidAt: paidAt ?? this.paidAt,
        note: note ?? this.note,
      );

  @override
  List<Object?> get props => [id, status, netGhs, orderId];
}

class TreasuryIntake extends Equatable {
  const TreasuryIntake({
    required this.id,
    required this.source,
    required this.refId,
    required this.amountGhs,
    required this.createdAt,
    this.merchandiseGhs = 0,
    this.shipmentGhs = 0,
    this.commissionGhs = 0,
    this.buyerId,
    this.note = '',
  });

  final String id;
  /// order | gift | other
  final String source;
  final String refId;
  final double amountGhs;
  final double merchandiseGhs;
  final double shipmentGhs;
  final double commissionGhs;
  final String? buyerId;
  final String createdAt;
  final String note;

  factory TreasuryIntake.fromJson(Map<String, dynamic> json) => TreasuryIntake(
        id: '${json['id'] ?? ''}',
        source: '${json['source'] ?? 'other'}',
        refId: '${json['refId'] ?? ''}',
        amountGhs: (json['amountGhs'] as num?)?.toDouble() ?? 0,
        merchandiseGhs: (json['merchandiseGhs'] as num?)?.toDouble() ?? 0,
        shipmentGhs: (json['shipmentGhs'] as num?)?.toDouble() ?? 0,
        commissionGhs: (json['commissionGhs'] as num?)?.toDouble() ?? 0,
        buyerId: json['buyerId'] as String?,
        createdAt: '${json['createdAt'] ?? ''}',
        note: '${json['note'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'refId': refId,
        'amountGhs': amountGhs,
        'merchandiseGhs': merchandiseGhs,
        'shipmentGhs': shipmentGhs,
        'commissionGhs': commissionGhs,
        if (buyerId != null) 'buyerId': buyerId,
        'createdAt': createdAt,
        if (note.isNotEmpty) 'note': note,
      };

  @override
  List<Object?> get props => [id, source, amountGhs];
}

class TreasurySnapshot {
  const TreasurySnapshot({
    this.collectedGhs = 0,
    this.commissionGhs = 0,
    this.pendingPayoutsGhs = 0,
    this.paidOutGhs = 0,
    this.shipmentHeldGhs = 0,
  });

  final double collectedGhs;
  final double commissionGhs;
  final double pendingPayoutsGhs;
  final double paidOutGhs;
  final double shipmentHeldGhs;

  /// Still sitting with Hubsom Admin after commission and unpaid seller nets.
  double get heldGhs =>
      HubsomCommission.roundGhs(collectedGhs - paidOutGhs);
}
