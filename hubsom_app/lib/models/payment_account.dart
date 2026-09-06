import 'package:equatable/equatable.dart';

/// Hubsom payment accounts.
///
/// Only the admin account may receive product payments. Seller and user
/// accounts are withdraw-only — they cash out payouts, they never collect
/// customer money.
class PaymentAccount extends Equatable {
  const PaymentAccount({
    required this.id,
    required this.ownerUserId,
    required this.email,
    required this.name,
    required this.kind,
    this.balanceGhs = 0,
    this.withdrawRail = '',
    this.withdrawHandle = '',
    this.creditedRefs = const [],
  });

  static const adminId = 'pay_admin';
  static const adminKind = 'admin_receive';
  static const userKind = 'user_withdraw';

  final String id;
  final String ownerUserId;
  final String email;
  final String name;
  /// admin_receive | user_withdraw
  final String kind;
  final double balanceGhs;
  final String withdrawRail;
  final String withdrawHandle;
  final List<String> creditedRefs;

  bool get isAdminReceive => kind == adminKind;
  bool get canReceive => isAdminReceive;
  bool get canWithdraw => kind == userKind;

  static String userIdFor(String ownerUserId) => 'pay_user_$ownerUserId';

  factory PaymentAccount.admin({
    required String ownerUserId,
    required String email,
    required String name,
    double balanceGhs = 0,
    List<String> creditedRefs = const [],
  }) =>
      PaymentAccount(
        id: adminId,
        ownerUserId: ownerUserId,
        email: email,
        name: name,
        kind: adminKind,
        balanceGhs: balanceGhs,
        creditedRefs: creditedRefs,
      );

  factory PaymentAccount.withdrawOnly({
    required String ownerUserId,
    required String email,
    required String name,
    double balanceGhs = 0,
    String withdrawRail = '',
    String withdrawHandle = '',
    List<String> creditedRefs = const [],
  }) =>
      PaymentAccount(
        id: userIdFor(ownerUserId),
        ownerUserId: ownerUserId,
        email: email,
        name: name,
        kind: userKind,
        balanceGhs: balanceGhs,
        withdrawRail: withdrawRail,
        withdrawHandle: withdrawHandle,
        creditedRefs: creditedRefs,
      );

  factory PaymentAccount.fromJson(Map<String, dynamic> json) => PaymentAccount(
        id: '${json['id'] ?? ''}',
        ownerUserId: '${json['ownerUserId'] ?? ''}',
        email: '${json['email'] ?? ''}',
        name: '${json['name'] ?? ''}',
        kind: '${json['kind'] ?? userKind}',
        balanceGhs: (json['balanceGhs'] as num?)?.toDouble() ?? 0,
        withdrawRail: '${json['withdrawRail'] ?? ''}',
        withdrawHandle: '${json['withdrawHandle'] ?? ''}',
        creditedRefs: (json['creditedRefs'] as List?)?.map((e) => '$e').toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerUserId': ownerUserId,
        'email': email,
        'name': name,
        'kind': kind,
        'balanceGhs': balanceGhs,
        if (withdrawRail.isNotEmpty) 'withdrawRail': withdrawRail,
        if (withdrawHandle.isNotEmpty) 'withdrawHandle': withdrawHandle,
        'creditedRefs': creditedRefs,
      };

  PaymentAccount copyWith({
    double? balanceGhs,
    String? withdrawRail,
    String? withdrawHandle,
    List<String>? creditedRefs,
  }) =>
      PaymentAccount(
        id: id,
        ownerUserId: ownerUserId,
        email: email,
        name: name,
        kind: kind,
        balanceGhs: balanceGhs ?? this.balanceGhs,
        withdrawRail: withdrawRail ?? this.withdrawRail,
        withdrawHandle: withdrawHandle ?? this.withdrawHandle,
        creditedRefs: creditedRefs ?? this.creditedRefs,
      );

  @override
  List<Object?> get props => [id, kind, balanceGhs];
}
