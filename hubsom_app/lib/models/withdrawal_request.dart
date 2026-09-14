import 'package:equatable/equatable.dart';

class WithdrawalRequest extends Equatable {
  const WithdrawalRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.amountGhs,
    required this.rail,
    required this.handle,
    required this.status,
    required this.createdAt,
    this.processedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final double amountGhs;
  final String rail;
  final String handle;
  /// pending | processed
  final String status;
  final String createdAt;
  final String? processedAt;

  bool get isPending => status == 'pending';
  bool get isProcessed => status == 'processed';

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) =>
      WithdrawalRequest(
        id: '${json['id'] ?? ''}',
        userId: '${json['userId'] ?? ''}',
        userName: '${json['userName'] ?? ''}',
        userEmail: '${json['userEmail'] ?? ''}',
        amountGhs: (json['amountGhs'] as num?)?.toDouble() ?? 0,
        rail: '${json['rail'] ?? ''}',
        handle: '${json['handle'] ?? ''}',
        status: '${json['status'] ?? 'pending'}',
        createdAt: '${json['createdAt'] ?? ''}',
        processedAt: json['processedAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'amountGhs': amountGhs,
        'rail': rail,
        'handle': handle,
        'status': status,
        'createdAt': createdAt,
        if (processedAt != null) 'processedAt': processedAt,
      };

  WithdrawalRequest copyWith({
    String? status,
    String? processedAt,
  }) =>
      WithdrawalRequest(
        id: id,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        amountGhs: amountGhs,
        rail: rail,
        handle: handle,
        status: status ?? this.status,
        createdAt: createdAt,
        processedAt: processedAt ?? this.processedAt,
      );

  @override
  List<Object?> get props => [id, userId, amountGhs, status, handle];
}
