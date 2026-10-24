import 'package:equatable/equatable.dart';

/// Standalone short video that can link to one or more products.
class ShopVideo extends Equatable {
  const ShopVideo({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.caption = '',
    this.productIds = const [],
    this.mimeType = 'video/mp4',
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String caption;
  final List<String> productIds;
  final String mimeType;
  final String createdAt;

  factory ShopVideo.fromJson(Map<String, dynamic> json) => ShopVideo(
        id: json['id'] as String,
        authorId: json['authorId'] as String? ?? '',
        authorName: json['authorName'] as String? ?? 'Hubsom user',
        caption: json['caption'] as String? ?? '',
        productIds: (json['productIds'] as List?)?.cast<String>() ?? const [],
        mimeType: json['mimeType'] as String? ?? 'video/mp4',
        createdAt: json['createdAt'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'caption': caption,
        'productIds': productIds,
        'mimeType': mimeType,
        'createdAt': createdAt,
      };

  @override
  List<Object?> get props => [id, authorId, productIds, createdAt];
}
