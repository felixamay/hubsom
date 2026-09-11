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
    this.thumbnailUrl,
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
  /// JPEG still grabbed from the clip — never a linked product photo.
  final String? thumbnailUrl;
  final String createdAt;

  /// Poster for cards / players: a frame from the video when we have one.
  String? get videoPosterUrl {
    final t = thumbnailUrl?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

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

  /// True when media is on Storage or Firestore chunks (not only local Hive).
  bool get hasPublishedMedia {
    final u = videoUrl?.trim() ?? '';
    return hasRemoteVideo || u.startsWith('hubsom-fs://');
  }

  static String? _url(Object? raw) {
    if (raw == null) return null;
    final v = '$raw'.trim();
    if (v.isEmpty || v == 'null' || v == 'undefined') return null;
    return v;
  }

  factory ShopVideo.fromJson(Map<String, dynamic> json) => ShopVideo(
        id: '${json['id']}',
        authorId: json['authorId'] as String? ?? '',
        authorName: json['authorName'] as String? ?? 'Hubsom user',
        authorImage: json['authorImage'] as String?,
        authorSellerId: json['authorSellerId'] as String?,
        caption: json['caption'] as String? ?? '',
        soundTitle: json['soundTitle'] as String? ?? '',
        productIds:
            (json['productIds'] as List?)?.map((e) => '$e').toList() ?? const [],
        mimeType: json['mimeType'] as String? ?? 'video/mp4',
        shareCount: (json['shareCount'] as num?)?.toInt() ?? 0,
        videoUrl: _url(json['videoUrl']) ?? _url(json['url']),
        thumbnailUrl: _url(json['thumbnailUrl']) ??
            _url(json['posterUrl']) ??
            _url(json['thumbUrl']),
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
        if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
          'thumbnailUrl': thumbnailUrl,
        'createdAt': createdAt,
      };

  /// Firestore payload. [thumbnail] is the portable still (https or a small
  /// `data:` JPEG) — pass null to write no still. Device-only
  /// `hubsom-blob://` refs are never written.
  Map<String, dynamic> toCloudJson({String? thumbnail}) {
    final map = toJson();
    final thumb = (thumbnail ?? '').trim();
    if (thumb.isEmpty || thumb.startsWith('hubsom-blob://')) {
      map.remove('thumbnailUrl');
    } else {
      map['thumbnailUrl'] = thumb;
    }
    return map;
  }

  ShopVideo copyWith({
    String? caption,
    String? soundTitle,
    String? authorImage,
    String? authorSellerId,
    List<String>? productIds,
    int? shareCount,
    String? videoUrl,
    String? thumbnailUrl,
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
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props =>
      [id, authorId, productIds, shareCount, videoUrl, thumbnailUrl, createdAt];
}
