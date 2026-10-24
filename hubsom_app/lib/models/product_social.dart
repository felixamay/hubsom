import 'package:equatable/equatable.dart';

class ProductComment extends Equatable {
  const ProductComment({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String productId;
  final String userId;
  final String userName;
  final String text;
  final String createdAt;

  factory ProductComment.fromJson(Map<String, dynamic> json) => ProductComment(
        id: json['id'] as String,
        productId: json['productId'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        userName: json['userName'] as String? ?? 'Buyer',
        text: json['text'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'userId': userId,
        'userName': userName,
        'text': text,
        'createdAt': createdAt,
      };

  @override
  List<Object?> get props => [id, productId, text, createdAt];
}

class TimelinePost extends Equatable {
  const TimelinePost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.productId,
    required this.productName,
    this.productImage,
    this.caption = '',
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String productId;
  final String productName;
  final String? productImage;
  final String caption;
  final String createdAt;

  factory TimelinePost.fromJson(Map<String, dynamic> json) => TimelinePost(
        id: json['id'] as String,
        authorId: json['authorId'] as String? ?? '',
        authorName: json['authorName'] as String? ?? 'Hubsom user',
        productId: json['productId'] as String? ?? '',
        productName: json['productName'] as String? ?? 'Product',
        productImage: json['productImage'] as String?,
        caption: json['caption'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'productId': productId,
        'productName': productName,
        if (productImage != null) 'productImage': productImage,
        'caption': caption,
        'createdAt': createdAt,
      };

  @override
  List<Object?> get props => [id, productId, authorId, createdAt];
}
