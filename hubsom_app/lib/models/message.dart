import 'package:equatable/equatable.dart';

class DirectMessage extends Equatable {
  const DirectMessage({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.text,
    required this.createdAt,
    this.fromUserName = '',
    this.toUserName = '',
    this.read = false,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final String text;
  final String createdAt;
  final String fromUserName;
  final String toUserName;
  final bool read;

  factory DirectMessage.fromJson(Map<String, dynamic> json) => DirectMessage(
        id: json['id'] as String,
        fromUserId: json['fromUserId'] as String? ?? '',
        toUserId: json['toUserId'] as String? ?? '',
        text: json['text'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
        fromUserName: json['fromUserName'] as String? ?? '',
        toUserName: json['toUserName'] as String? ?? '',
        read: json['read'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'text': text,
        'createdAt': createdAt,
        'fromUserName': fromUserName,
        'toUserName': toUserName,
        'read': read,
      };

  DirectMessage copyWith({bool? read}) => DirectMessage(
        id: id,
        fromUserId: fromUserId,
        toUserId: toUserId,
        text: text,
        createdAt: createdAt,
        fromUserName: fromUserName,
        toUserName: toUserName,
        read: read ?? this.read,
      );

  @override
  List<Object?> get props => [id, fromUserId, toUserId, text, read];
}

class ConversationPreview extends Equatable {
  const ConversationPreview({
    required this.userId,
    required this.name,
    this.avatar,
    required this.lastMessage,
    required this.updatedAt,
    this.unreadCount = 0,
  });

  final String userId;
  final String name;
  final String? avatar;
  final String lastMessage;
  final String updatedAt;
  final int unreadCount;

  factory ConversationPreview.fromJson(Map<String, dynamic> json) =>
      ConversationPreview(
        userId: json['userId'] as String,
        name: json['name'] as String? ?? 'User',
        avatar: json['avatar'] as String?,
        lastMessage: json['lastMessage'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [userId, lastMessage, unreadCount];
}
