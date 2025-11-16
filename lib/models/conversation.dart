class ConversationModel {
  final String id;
  final List<String> participants;
  final String createdBy;
  final String? lastMessageId;
  final DateTime? lastActivity;
  final int user1UnreadCount;
  final int user2UnreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ConversationModel({
    required this.id,
    required this.participants,
    required this.createdBy,
    this.lastMessageId,
    this.lastActivity,
    this.user1UnreadCount = 0,
    this.user2UnreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> map, String id) {
    return ConversationModel(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      createdBy: map['createdBy'] ?? '',
      lastMessageId: map['lastMessageId'],
      lastActivity: map['lastActivity']?.toDate(),
      user1UnreadCount: map['user1UnreadCount'] ?? 0,
      user2UnreadCount: map['user2UnreadCount'] ?? 0,
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: map['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'createdBy': createdBy,
      'lastMessageId': lastMessageId,
      'lastActivity': lastActivity,
      'user1UnreadCount': user1UnreadCount,
      'user2UnreadCount': user2UnreadCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  ConversationModel copyWith({
    String? id,
    List<String>? participants,
    String? createdBy,
    String? lastMessageId,
    DateTime? lastActivity,
    int? user1UnreadCount,
    int? user2UnreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      createdBy: createdBy ?? this.createdBy,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastActivity: lastActivity ?? this.lastActivity,
      user1UnreadCount: user1UnreadCount ?? this.user1UnreadCount,
      user2UnreadCount: user2UnreadCount ?? this.user2UnreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get the other participant's ID
  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere((id) => id != currentUserId);
  }

  /// Get unread count for a specific user
  int getUnreadCountForUser(String userId) {
    if (participants.isEmpty || participants.length != 2) return 0;
    return participants[0] == userId ? user1UnreadCount : user2UnreadCount;
  }
}