import 'package:equatable/equatable.dart';

/// Standalone short video that can link to one or more products.
class ShopVideo extends Equatable {
  const ShopVideo({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorImage,
    this.authorSellerId,
    this.caption = '',
    this.soundTitle = '',
    this.productIds = const [],
    this.mimeType = 'video/mp4',
    this.shareCount = 0,
    this.videoUrl,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorImage;
  final String? authorSellerId;
  final String caption;
  /// Shown as the scrolling "Original sound" line (TikTok-style).
  final String soundTitle;
  final List<String> productIds;
  final String mimeType;
  final int shareCount;
  /// Firebase Storage (or CDN) URL so other devices can play the clip.
  final String? videoUrl;
  final String createdAt;

  String get displaySound {
    final s = soundTitle.trim();
    if (s.isNotEmpty) return s;
    return 'Original sound - $authorName';
  }

  bool get hasRemoteVideo {
    final u = videoUrl?.trim() ?? '';
    return u.startsWith('http://') ||
        u.startsWith('https://') ||
        u.startsWith('blob:') ||
        u.startsWith('data:');
  }

  factory ShopVideo.fromJson(Map<String, dynamic> json) => ShopVideo(
        id: json['id'] as String,
        authorId: json['authorId'] as String? ?? '',
        authorName: json['authorName'] as String? ?? 'Hubsom user',
        authorImage: json['authorImage'] as String?,
        authorSellerId: json['authorSellerId'] as String?,
        caption: json['caption'] as String? ?? '',
        soundTitle: json['soundTitle'] as String? ?? '',
        productIds: (json['productIds'] as List?)?.cast<String>() ?? const [],
        mimeType: json['mimeType'] as String? ?? 'video/mp4',
        shareCount: (json['shareCount'] as num?)?.toInt() ?? 0,
        videoUrl: json['videoUrl'] as String? ?? json['url'] as String?,
        createdAt: json['createdAt'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        if (authorImage != null) 'authorImage': authorImage,
        if (authorSellerId != null) 'authorSellerId': authorSellerId,
        'caption': caption,
        'soundTitle': soundTitle,
        'productIds': productIds,
        'mimeType': mimeType,
        'shareCount': shareCount,
        if (videoUrl != null && videoUrl!.isNotEmpty) 'videoUrl': videoUrl,
        'createdAt': createdAt,
      };

  ShopVideo copyWith({
    String? caption,
    String? soundTitle,
    String? authorImage,
    String? authorSellerId,
    List<String>? productIds,
    int? shareCount,
    String? videoUrl,
  }) =>
      ShopVideo(
        id: id,
        authorId: authorId,
        authorName: authorName,
        authorImage: authorImage ?? this.authorImage,
        authorSellerId: authorSellerId ?? this.authorSellerId,
        caption: caption ?? this.caption,
        soundTitle: soundTitle ?? this.soundTitle,
        productIds: productIds ?? this.productIds,
        mimeType: mimeType,
        shareCount: shareCount ?? this.shareCount,
        videoUrl: videoUrl ?? this.videoUrl,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props =>
      [id, authorId, productIds, shareCount, videoUrl, createdAt];
}
