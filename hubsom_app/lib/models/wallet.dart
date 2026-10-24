import 'package:equatable/equatable.dart';

class WalletTransaction extends Equatable {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amountGhs,
    required this.description,
    required this.createdAt,
    this.reference,
  });

  final String id;
  final String type; // credit | debit | payout | topup
  final double amountGhs;
  final String description;
  final String createdAt;
  final String? reference;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] as String,
        type: json['type'] as String? ?? 'credit',
        amountGhs: (json['amountGhs'] as num?)?.toDouble() ?? 0,
        description: json['description'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
        reference: json['reference'] as String?,
      );

  @override
  List<Object?> get props => [id, type, amountGhs];
}

class Wallet extends Equatable {
  const Wallet({
    required this.balanceGhs,
    this.currency = 'GHS',
    this.transactions = const [],
  });

  final double balanceGhs;
  final String currency;
  final List<WalletTransaction> transactions;

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        balanceGhs: (json['balanceGhs'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'GHS',
        transactions: (json['transactions'] as List?)
                ?.map((e) =>
                    WalletTransaction.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [balanceGhs, transactions];
}
