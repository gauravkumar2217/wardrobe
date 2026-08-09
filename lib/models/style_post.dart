/// Community Style Feed post (look photo) — not a wardrobe cloth item.
class StylePost {
  final String id;
  final String userId;
  final String imageUrl;
  final String? caption;
  final String visibility;
  final List<String> sharedWith;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;
  final DateTime? createdAt;
  final StylePostUser? user;

  StylePost({
    required this.id,
    required this.userId,
    required this.imageUrl,
    this.caption,
    this.visibility = 'friends',
    this.sharedWith = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedByMe = false,
    this.createdAt,
    this.user,
  });

  factory StylePost.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final raw = json['created_at'] ?? json['createdAt'];
    if (raw is String && raw.isNotEmpty) {
      created = DateTime.tryParse(raw);
    }

    return StylePost(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      imageUrl:
          json['image_url']?.toString() ?? json['imageUrl']?.toString() ?? '',
      caption: json['caption']?.toString(),
      visibility: json['visibility']?.toString() ?? 'friends',
      sharedWith: () {
        final raw = json['shared_with'] ?? json['sharedWith'];
        if (raw is List) {
          return raw.map((e) => e.toString()).toList();
        }
        return <String>[];
      }(),
      likesCount: (json['likes_count'] as num?)?.toInt() ??
          (json['likesCount'] as num?)?.toInt() ??
          0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ??
          (json['commentsCount'] as num?)?.toInt() ??
          0,
      likedByMe: json['liked_by_me'] == true || json['likedByMe'] == true,
      createdAt: created,
      user: json['user'] is Map
          ? StylePostUser.fromJson(Map<String, dynamic>.from(json['user'] as Map))
          : null,
    );
  }

  StylePost copyWith({
    int? likesCount,
    int? commentsCount,
    bool? likedByMe,
  }) {
    return StylePost(
      id: id,
      userId: userId,
      imageUrl: imageUrl,
      caption: caption,
      visibility: visibility,
      sharedWith: sharedWith,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      likedByMe: likedByMe ?? this.likedByMe,
      createdAt: createdAt,
      user: user,
    );
  }
}

class StylePostUser {
  final String id;
  final String? displayName;
  final String? username;
  final String? photoUrl;

  StylePostUser({
    required this.id,
    this.displayName,
    this.username,
    this.photoUrl,
  });

  factory StylePostUser.fromJson(Map<String, dynamic> json) {
    return StylePostUser(
      id: json['id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ??
          json['displayName']?.toString(),
      username: json['username']?.toString(),
      photoUrl:
          json['photo_url']?.toString() ?? json['photoUrl']?.toString(),
    );
  }

  String get displayLabel {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    if (username != null && username!.trim().isNotEmpty) {
      return username!.trim();
    }
    return 'User';
  }
}
