import 'package:equatable/equatable.dart';

class StreamHost extends Equatable {
  const StreamHost({
    required this.id,
    required this.name,
    required this.role,
    required this.avatar,
  });

  final String id;
  final String name;
  final String role;
  final String avatar;

  factory StreamHost.fromJson(Map<String, dynamic> json) => StreamHost(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? 'host',
        avatar: json['avatar'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id, role];
}

class LiveAuction extends Equatable {
  const LiveAuction({
    required this.id,
    required this.productId,
    required this.startingBidGhs,
    required this.currentBidGhs,
    required this.minIncrementGhs,
    required this.endsAt,
    this.bidderCount = 0,
    this.highestBidder,
    required this.status,
  });

  final String id;
  final String productId;
  final double startingBidGhs;
  final double currentBidGhs;
  final double minIncrementGhs;
  final String endsAt;
  final int bidderCount;
  final String? highestBidder;
  final String status;

  factory LiveAuction.fromJson(Map<String, dynamic> json) => LiveAuction(
        id: json['id'] as String,
        productId: json['productId'] as String? ?? '',
        startingBidGhs: (json['startingBidGhs'] as num?)?.toDouble() ?? 0,
        currentBidGhs: (json['currentBidGhs'] as num?)?.toDouble() ?? 0,
        minIncrementGhs: (json['minIncrementGhs'] as num?)?.toDouble() ?? 1,
        endsAt: json['endsAt'] as String? ?? '',
        bidderCount: (json['bidderCount'] as num?)?.toInt() ?? 0,
        highestBidder: json['highestBidder'] as String?,
        status: json['status'] as String? ?? 'upcoming',
      );

  @override
  List<Object?> get props => [id, productId, currentBidGhs, status];
}

class LiveStream extends Equatable {
  const LiveStream({
    required this.id,
    required this.title,
    required this.description,
    required this.sellerId,
    required this.status,
    required this.channelName,
    required this.cover,
    this.viewerCount = 0,
    this.peakViewers = 0,
    this.startedAt,
    this.endedAt,
    this.recordingUrl,
    this.productIds = const [],
    this.pinnedProductId,
    this.hosts = const [],
    this.auction,
    this.categories = const [],
    this.latencyMs = 0,
    this.isMultiHost = false,
    this.replayAvailable = false,
  });

  final String id;
  final String title;
  final String description;
  final String sellerId;
  final String status;
  final String channelName;
  final String cover;
  final int viewerCount;
  final int peakViewers;
  final String? startedAt;
  final String? endedAt;
  final String? recordingUrl;
  final List<String> productIds;
  final String? pinnedProductId;
  final List<StreamHost> hosts;
  final LiveAuction? auction;
  final List<String> categories;
  final int latencyMs;
  final bool isMultiHost;
  final bool replayAvailable;

  bool get isLive => status == 'live';

  factory LiveStream.fromJson(Map<String, dynamic> json) => LiveStream(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        sellerId: json['sellerId'] as String? ?? '',
        status: json['status'] as String? ?? 'scheduled',
        channelName: json['channelName'] as String? ?? json['id'] as String,
        cover: json['cover'] as String? ?? '',
        viewerCount: (json['viewerCount'] as num?)?.toInt() ?? 0,
        peakViewers: (json['peakViewers'] as num?)?.toInt() ?? 0,
        startedAt: json['startedAt'] as String?,
        endedAt: json['endedAt'] as String?,
        recordingUrl: json['recordingUrl'] as String?,
        productIds: (json['productIds'] as List?)?.cast<String>() ?? const [],
        pinnedProductId: json['pinnedProductId'] as String?,
        hosts: (json['hosts'] as List?)
                ?.map((e) => StreamHost.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        auction: json['auction'] != null
            ? LiveAuction.fromJson(Map<String, dynamic>.from(json['auction'] as Map))
            : null,
        categories: (json['categories'] as List?)?.cast<String>() ?? const [],
        latencyMs: (json['latencyMs'] as num?)?.toInt() ?? 0,
        isMultiHost: json['isMultiHost'] as bool? ?? false,
        replayAvailable: json['replayAvailable'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, status, viewerCount, pinnedProductId, auction];
}

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.streamId,
    required this.userId,
    required this.displayName,
    required this.text,
    required this.createdAt,
    this.moderated = false,
  });

  final String id;
  final String streamId;
  final String userId;
  final String displayName;
  final String text;
  final String createdAt;
  final bool moderated;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        streamId: json['streamId'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'Viewer',
        text: json['text'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
        moderated: json['moderated'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, text, moderated];
}

class LiveReaction extends Equatable {
  const LiveReaction({
    required this.id,
    required this.streamId,
    required this.emoji,
    required this.x,
    required this.createdAt,
  });

  final String id;
  final String streamId;
  final String emoji;
  final double x;
  final int createdAt;

  factory LiveReaction.fromJson(Map<String, dynamic> json) => LiveReaction(
        id: json['id'] as String,
        streamId: json['streamId'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '❤️',
        x: (json['x'] as num?)?.toDouble() ?? 0.5,
        createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [id, emoji, createdAt];
}
