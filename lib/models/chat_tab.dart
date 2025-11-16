class ChatTabModel {
  final String id;
  final String conversationId;
  final String tabName;
  final int tabOrder;
  final String createdBy;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatTabModel({
    required this.id,
    required this.conversationId,
    required this.tabName,
    required this.tabOrder,
    required this.createdBy,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatTabModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatTabModel(
      id: id,
      conversationId: map['conversationId'] ?? '',
      tabName: map['tabName'] ?? '',
      tabOrder: map['tabOrder'] ?? 0,
      createdBy: map['createdBy'] ?? '',
      isDefault: map['isDefault'] ?? false,
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: map['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  /// Helper method to check if this is the "add new tab" placeholder
  bool get isAddNewTab => id == 'add_new_tab';

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'tabName': tabName,
      'tabOrder': tabOrder,
      'createdBy': createdBy,
      'isDefault': isDefault,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  ChatTabModel copyWith({
    String? id,
    String? conversationId,
    String? tabName,
    int? tabOrder,
    String? createdBy,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatTabModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      tabName: tabName ?? this.tabName,
      tabOrder: tabOrder ?? this.tabOrder,
      createdBy: createdBy ?? this.createdBy,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}