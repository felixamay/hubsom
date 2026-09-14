import 'package:equatable/equatable.dart';

class HubsomNotification extends Equatable {
  const HubsomNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.route,
    this.streamId,
    this.sellerId,
    this.read = false,
  });

  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final String createdAt;
  final String? route;
  final String? streamId;
  final String? sellerId;
  final bool read;

  bool get isLiveAlert => type == 'seller_live';

  factory HubsomNotification.fromJson(Map<String, dynamic> json) =>
      HubsomNotification(
        id: json['id'] as String,
        userId: json['userId'] as String? ?? '',
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
        route: json['route'] as String?,
        streamId: json['streamId'] as String?,
        sellerId: json['sellerId'] as String?,
        read: json['read'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'type': type,
        'title': title,
        'body': body,
        'createdAt': createdAt,
        if (route != null) 'route': route,
        if (streamId != null) 'streamId': streamId,
        if (sellerId != null) 'sellerId': sellerId,
        'read': read,
      };

  HubsomNotification copyWith({bool? read}) => HubsomNotification(
        id: id,
        userId: userId,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        route: route,
        streamId: streamId,
        sellerId: sellerId,
        read: read ?? this.read,
      );

  @override
  List<Object?> get props => [id, userId, type, streamId, read];
}
