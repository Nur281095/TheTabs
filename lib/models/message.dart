enum MessageType { text, image, file }

class MessageModel {
  final String id;
  final String tabId;
  final String senderId;
  final MessageType messageType;
  final String? content;
  final String? mediaUrl;
  final String? mediaType;
  final String? replyToMessageId;
  final DateTime sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final bool isDeleted;
  final int messageOrder;

  MessageModel({
    required this.id,
    required this.tabId,
    required this.senderId,
    required this.messageType,
    this.content,
    this.mediaUrl,
    this.mediaType,
    this.replyToMessageId,
    required this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.isDeleted = false,
    required this.messageOrder,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      tabId: map['tabId'] ?? '',
      senderId: map['senderId'] ?? '',
      messageType: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == map['messageType'],
        orElse: () => MessageType.text,
      ),
      content: map['content'],
      mediaUrl: map['mediaUrl'],
      mediaType: map['mediaType'],
      replyToMessageId: map['replyToMessageId'],
      sentAt: map['sentAt']?.toDate() ?? DateTime.now(),
      deliveredAt: map['deliveredAt']?.toDate(),
      readAt: map['readAt']?.toDate(),
      isDeleted: map['isDeleted'] ?? false,
      messageOrder: map['messageOrder'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tabId': tabId,
      'senderId': senderId,
      'messageType': messageType.toString().split('.').last,
      'content': content,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'replyToMessageId': replyToMessageId,
      'sentAt': sentAt,
      'deliveredAt': deliveredAt,
      'readAt': readAt,
      'isDeleted': isDeleted,
      'messageOrder': messageOrder,
    };
  }

  MessageModel copyWith({
    String? id,
    String? tabId,
    String? senderId,
    MessageType? messageType,
    String? content,
    String? mediaUrl,
    String? mediaType,
    String? replyToMessageId,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? readAt,
    bool? isDeleted,
    int? messageOrder,
  }) {
    return MessageModel(
      id: id ?? this.id,
      tabId: tabId ?? this.tabId,
      senderId: senderId ?? this.senderId,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      isDeleted: isDeleted ?? this.isDeleted,
      messageOrder: messageOrder ?? this.messageOrder,
    );
  }

  /// Check if message is from current user
  bool isFromCurrentUser(String currentUserId) {
    return senderId == currentUserId;
  }

  /// Check if message has been read
  bool get isRead => readAt != null;

  /// Check if message has been delivered
  bool get isDelivered => deliveredAt != null;

  /// Get message status for UI
  String get status {
    if (isRead) return 'Read';
    if (isDelivered) return 'Delivered';
    return 'Sent';
  }
}