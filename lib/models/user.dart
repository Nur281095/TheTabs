class UserModel {
  final String uid;
  final String phoneNumber;
  final String? displayName;
  final String? profilePhotoUrl;
  final String? about;
  final String onlineStatus; // 'online', 'offline', 'away'
  final DateTime? lastSeen;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.phoneNumber,
    this.displayName,
    this.profilePhotoUrl,
    this.about,
    this.onlineStatus = 'offline',
    this.lastSeen,
    this.isAvailable = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      displayName: map['displayName'],
      profilePhotoUrl: map['profilePhotoUrl'],
      about: map['about'],
      onlineStatus: map['onlineStatus'] ?? 'offline',
      lastSeen: map['lastSeen']?.toDate(),
      isAvailable: map['isAvailable'] ?? true,
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: map['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'profilePhotoUrl': profilePhotoUrl,
      'about': about,
      'onlineStatus': onlineStatus,
      'lastSeen': lastSeen,
      'isAvailable': isAvailable,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  UserModel copyWith({
    String? uid,
    String? phoneNumber,
    String? displayName,
    String? profilePhotoUrl,
    String? about,
    String? onlineStatus,
    DateTime? lastSeen,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      about: about ?? this.about,
      onlineStatus: onlineStatus ?? this.onlineStatus,
      lastSeen: lastSeen ?? this.lastSeen,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}