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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'avatar': avatar,
      };

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
    this.highestBidderId,
    this.highestBidderEmail,
    required this.status,
    this.recentBids = const [],
    this.orderId,
    this.askingPriceGhs,
  });

  final String id;
  final String productId;
  final double startingBidGhs;
  final double currentBidGhs;
  final double minIncrementGhs;
  final String endsAt;
  final int bidderCount;
  final String? highestBidder;
  final String? highestBidderId;
  final String? highestBidderEmail;
  final String status;
  final List<AuctionBid> recentBids;
  /// Set when the winning bid is converted into a seller order.
  final String? orderId;
  /// Seller-only reserve / asking price (hidden from viewers).
  final double? askingPriceGhs;

  double get nextMinBidGhs => currentBidGhs + minIncrementGhs;

  bool get hasAskingPrice =>
      askingPriceGhs != null && askingPriceGhs! > 0;

  /// True when current high bid meets the seller's asking price (or none set).
  bool get askMet {
    if (!hasAskingPrice) return true;
    return currentBidGhs + 0.001 >= askingPriceGhs!;
  }

  bool get isOpen {
    if (status != 'open') return false;
    final left = timeLeft;
    return left == null || left > Duration.zero;
  }

  bool get needsFinalize =>
      orderId == null &&
      status == 'open' &&
      !isOpen &&
      (highestBidderId != null || highestBidder != null) &&
      askMet;

  /// Timer ended but ask not met — seller can extend.
  bool get awaitingExtend =>
      orderId == null &&
      !isOpen &&
      status != 'sold' &&
      status != 'closed' &&
      !askMet;

  Duration? get timeLeft {
    try {
      final end = DateTime.parse(endsAt).toUtc();
      final left = end.difference(DateTime.now().toUtc());
      return left.isNegative ? Duration.zero : left;
    } catch (_) {
      return null;
    }
  }

  factory LiveAuction.fromJson(Map<String, dynamic> json) => LiveAuction(
        id: json['id'] as String,
        productId: json['productId'] as String? ?? '',
        startingBidGhs: (json['startingBidGhs'] as num?)?.toDouble() ?? 0,
        currentBidGhs: (json['currentBidGhs'] as num?)?.toDouble() ?? 0,
        minIncrementGhs: (json['minIncrementGhs'] as num?)?.toDouble() ?? 1,
        endsAt: json['endsAt'] as String? ?? '',
        bidderCount: (json['bidderCount'] as num?)?.toInt() ?? 0,
        highestBidder: json['highestBidder'] as String?,
        highestBidderId: json['highestBidderId'] as String?,
        highestBidderEmail: json['highestBidderEmail'] as String?,
        status: json['status'] as String? ?? 'upcoming',
        recentBids: (json['recentBids'] as List?)
                ?.map((e) => AuctionBid.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        orderId: json['orderId'] as String?,
        askingPriceGhs: (json['askingPriceGhs'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'startingBidGhs': startingBidGhs,
        'currentBidGhs': currentBidGhs,
        'minIncrementGhs': minIncrementGhs,
        'endsAt': endsAt,
        'bidderCount': bidderCount,
        if (highestBidder != null) 'highestBidder': highestBidder,
        if (highestBidderId != null) 'highestBidderId': highestBidderId,
        if (highestBidderEmail != null) 'highestBidderEmail': highestBidderEmail,
        'status': status,
        'recentBids': recentBids.map((b) => b.toJson()).toList(),
        if (orderId != null) 'orderId': orderId,
        if (askingPriceGhs != null) 'askingPriceGhs': askingPriceGhs,
      };

  LiveAuction copyWith({
    double? currentBidGhs,
    int? bidderCount,
    String? highestBidder,
    String? highestBidderId,
    String? highestBidderEmail,
    String? status,
    String? endsAt,
    List<AuctionBid>? recentBids,
    String? orderId,
    double? askingPriceGhs,
  }) =>
      LiveAuction(
        id: id,
        productId: productId,
        startingBidGhs: startingBidGhs,
        currentBidGhs: currentBidGhs ?? this.currentBidGhs,
        minIncrementGhs: minIncrementGhs,
        endsAt: endsAt ?? this.endsAt,
        bidderCount: bidderCount ?? this.bidderCount,
        highestBidder: highestBidder ?? this.highestBidder,
        highestBidderId: highestBidderId ?? this.highestBidderId,
        highestBidderEmail: highestBidderEmail ?? this.highestBidderEmail,
        status: status ?? this.status,
        recentBids: recentBids ?? this.recentBids,
        orderId: orderId ?? this.orderId,
        askingPriceGhs: askingPriceGhs ?? this.askingPriceGhs,
      );

  @override
  List<Object?> get props =>
      [id, productId, currentBidGhs, status, endsAt, bidderCount, orderId, askingPriceGhs];
}

class AuctionBid extends Equatable {
  const AuctionBid({
    required this.bidderName,
    required this.amountGhs,
    required this.at,
    this.bidderId,
  });

  final String bidderName;
  final double amountGhs;
  final String at;
  final String? bidderId;

  factory AuctionBid.fromJson(Map<String, dynamic> json) => AuctionBid(
        bidderName: json['bidderName'] as String? ?? 'Bidder',
        amountGhs: (json['amountGhs'] as num?)?.toDouble() ?? 0,
        at: json['at'] as String? ?? '',
        bidderId: json['bidderId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'bidderName': bidderName,
        'amountGhs': amountGhs,
        'at': at,
        if (bidderId != null) 'bidderId': bidderId,
      };

  @override
  List<Object?> get props => [bidderName, amountGhs, at, bidderId];
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'sellerId': sellerId,
        'status': status,
        'channelName': channelName,
        'cover': cover,
        'viewerCount': viewerCount,
        'peakViewers': peakViewers,
        if (startedAt != null) 'startedAt': startedAt,
        if (endedAt != null) 'endedAt': endedAt,
        if (recordingUrl != null) 'recordingUrl': recordingUrl,
        'productIds': productIds,
        if (pinnedProductId != null) 'pinnedProductId': pinnedProductId,
        'hosts': hosts.map((h) => h.toJson()).toList(),
        if (auction != null) 'auction': auction!.toJson(),
        'categories': categories,
        'latencyMs': latencyMs,
        'isMultiHost': isMultiHost,
        'replayAvailable': replayAvailable,
      };

  LiveStream copyWith({
    String? status,
    int? viewerCount,
    int? peakViewers,
    String? endedAt,
    String? pinnedProductId,
    List<String>? productIds,
    LiveAuction? auction,
    bool clearPinned = false,
    bool clearAuction = false,
    bool? replayAvailable,
  }) =>
      LiveStream(
        id: id,
        title: title,
        description: description,
        sellerId: sellerId,
        status: status ?? this.status,
        channelName: channelName,
        cover: cover,
        viewerCount: viewerCount ?? this.viewerCount,
        peakViewers: peakViewers ?? this.peakViewers,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        recordingUrl: recordingUrl,
        productIds: productIds ?? this.productIds,
        pinnedProductId:
            clearPinned ? null : (pinnedProductId ?? this.pinnedProductId),
        hosts: hosts,
        auction: clearAuction ? null : (auction ?? this.auction),
        categories: categories,
        latencyMs: latencyMs,
        isMultiHost: isMultiHost,
        replayAvailable: replayAvailable ?? this.replayAvailable,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'streamId': streamId,
        'userId': userId,
        'displayName': displayName,
        'text': text,
        'createdAt': createdAt,
        'moderated': moderated,
      };

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
