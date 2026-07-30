import 'package:equatable/equatable.dart';

class ProductReview extends Equatable {
  const ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String productId;
  final String userId;
  final String userName;
  final int rating;
  final String comment;
  final String createdAt;

  factory ProductReview.fromJson(Map<String, dynamic> json) => ProductReview(
        id: json['id'] as String,
        productId: json['productId'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        userName: json['userName'] as String? ?? 'Buyer',
        rating: (json['rating'] as num?)?.toInt() ?? 5,
        comment: json['comment'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id, productId, rating];
}
