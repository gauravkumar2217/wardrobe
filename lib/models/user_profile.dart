import 'package:cloud_firestore/cloud_firestore.dart';

/// User Profile model with settings and privacy controls
class UserProfile {
  final String? displayName;
  final String? username;
  final String? photoUrl;
  final String? email;
  final String? phone;
  final String? gender;
  final DateTime? dateOfBirth;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final UserSettings? settings;

  UserProfile({
    this.displayName,
    this.username,
    this.photoUrl,
    this.email,
    this.phone,
    this.gender,
    this.dateOfBirth,
    this.createdAt,
    this.updatedAt,
    this.settings,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      displayName: json['displayName'] as String?,
      username: json['username'] as String?,
      photoUrl: json['photoUrl'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String? ?? json['phoneNumber'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: json['dateOfBirth'] != null
          ? (json['dateOfBirth'] as Timestamp).toDate()
          : null,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
      settings: json['settings'] != null
          ? UserSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (displayName != null) 'displayName': displayName,
      if (username != null) 'username': username,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (gender != null) 'gender': gender,
      if (dateOfBirth != null) 'dateOfBirth': Timestamp.fromDate(dateOfBirth!),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (settings != null) 'settings': settings!.toJson(),
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? username,
    String? photoUrl,
    String? email,
    String? phone,
    String? gender,
    DateTime? dateOfBirth,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserSettings? settings,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      settings: settings ?? this.settings,
    );
  }

  bool get isComplete {
    return displayName != null && 
           displayName!.isNotEmpty &&
           username != null &&
           username!.isNotEmpty;
  }
}

/// User notification settings
class NotificationSettings {
  final bool friendRequests;
  final bool friendAccepts;
  final bool dmMessages;
  final bool clothLikes;
  final bool clothComments;
  final bool suggestions;
  final bool scheduledNotifications;
  final String? quietHoursStart; // e.g., "22:00"
  final String? quietHoursEnd; // e.g., "08:00"

  NotificationSettings({
    this.friendRequests = true,
    this.friendAccepts = true,
    this.dmMessages = true,
    this.clothLikes = true,
    this.clothComments = true,
    this.suggestions = true,
    this.scheduledNotifications = true,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    // Helper to safely get bool value
    bool getBool(String key, {bool defaultValue = true}) {
      final value = json[key];
      if (value == null) return defaultValue;
      if (value is bool) return value;
      return defaultValue;
    }

    return NotificationSettings(
      friendRequests: getBool('friendRequests'),
      friendAccepts: getBool('friendAccepts'),
      dmMessages: getBool('dmMessages'),
      clothLikes: getBool('clothLikes'),
      clothComments: getBool('clothComments'),
      suggestions: getBool('suggestions'),
      scheduledNotifications: getBool('scheduledNotifications'),
      quietHoursStart: json['quietHoursStart'] as String?,
      quietHoursEnd: json['quietHoursEnd'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'friendRequests': friendRequests,
      'friendAccepts': friendAccepts,
      'dmMessages': dmMessages,
      'clothLikes': clothLikes,
      'clothComments': clothComments,
      'suggestions': suggestions,
      'scheduledNotifications': scheduledNotifications,
      if (quietHoursStart != null) 'quietHoursStart': quietHoursStart,
      if (quietHoursEnd != null) 'quietHoursEnd': quietHoursEnd,
    };
  }
}

/// User privacy settings
class PrivacySettings {
  final String profileVisibility; // "public", "friends", "private"
  final String wardrobeVisibility; // "public", "friends", "private"
  final bool allowDmFromNonFriends;

  PrivacySettings({
    this.profileVisibility = 'friends',
    this.wardrobeVisibility = 'friends',
    this.allowDmFromNonFriends = false,
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    return PrivacySettings(
      profileVisibility: json['profileVisibility'] as String? ?? 'friends',
      wardrobeVisibility: json['wardrobeVisibility'] as String? ?? 'friends',
      allowDmFromNonFriends: json['allowDmFromNonFriends'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profileVisibility': profileVisibility,
      'wardrobeVisibility': wardrobeVisibility,
      'allowDmFromNonFriends': allowDmFromNonFriends,
    };
  }
}

/// Complete user settings
class UserSettings {
  final NotificationSettings notifications;
  final PrivacySettings privacy;

  UserSettings({
    NotificationSettings? notifications,
    PrivacySettings? privacy,
  })  : notifications = notifications ?? NotificationSettings(),
        privacy = privacy ?? PrivacySettings();

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      notifications: json['notifications'] != null
          ? NotificationSettings.fromJson(
              json['notifications'] as Map<String, dynamic>)
          : null,
      privacy: json['privacy'] != null
          ? PrivacySettings.fromJson(json['privacy'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notifications': notifications.toJson(),
      'privacy': privacy.toJson(),
    };
  }
}
