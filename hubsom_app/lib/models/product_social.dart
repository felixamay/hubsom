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
    this.authorImage,
    this.type = 'product',
    this.productId = '',
    this.productName = '',
    this.productImage,
    this.videoId,
    this.videoUrl,
    this.streamId,
    this.caption = '',
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorImage;
  /// `product` | `video` | `live`
  final String type;
  final String productId;
  final String productName;
  final String? productImage;
  final String? videoId;
  /// Remote shop-video URL when this post is a video.
  final String? videoUrl;
  /// Live show id when this post is a shared live.
  final String? streamId;
  final String caption;
  final String createdAt;

  bool get isVideo => type == 'video' || (videoId != null && videoId!.isNotEmpty);

  bool get isLivePost =>
      type == 'live' || (streamId != null && streamId!.isNotEmpty);

  factory TimelinePost.fromJson(Map<String, dynamic> json) {
    final videoId = json['videoId'] as String?;
    final streamId = json['streamId'] as String?;
    final rawType = json['type'] as String?;
    final type = (rawType != null && rawType.isNotEmpty)
        ? rawType
        : (videoId != null && videoId.isNotEmpty
            ? 'video'
            : (streamId != null && streamId.isNotEmpty ? 'live' : 'product'));
    return TimelinePost(
      id: json['id'] as String,
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? 'Hubsom user',
      authorImage: json['authorImage'] as String?,
      type: type,
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? 'Product',
      productImage: json['productImage'] as String?,
      videoId: videoId,
      videoUrl: json['videoUrl'] as String?,
      streamId: streamId,
      caption: json['caption'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        if (authorImage != null) 'authorImage': authorImage,
        'type': type,
        'productId': productId,
        'productName': productName,
        if (productImage != null) 'productImage': productImage,
        if (videoId != null) 'videoId': videoId,
        if (videoUrl != null && videoUrl!.isNotEmpty) 'videoUrl': videoUrl,
        if (streamId != null && streamId!.isNotEmpty) 'streamId': streamId,
        'caption': caption,
        'createdAt': createdAt,
      };

  @override
  List<Object?> get props =>
      [id, type, productId, videoId, videoUrl, streamId, authorId, createdAt];
}
