/// Friend Request model (Laravel API + legacy Firestore-compatible parsing).
class FriendRequest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String status; // pending | accepted | rejected | canceled
  final DateTime createdAt;
  final DateTime updatedAt;
  /// From nested `from_user` on API — avoids extra profile fetches.
  final String? fromDisplayName;
  final String? fromUsername;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.fromDisplayName,
    this.fromUsername,
  });

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    // Firestore Timestamp duck-typing
    try {
      final dynamic d = value.toDate();
      if (d is DateTime) return d;
    } catch (_) {}
    return DateTime.now();
  }

  factory FriendRequest.fromApiJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    Map? fromUser;
    final rawFrom = json['from_user'] ?? json['fromUser'];
    if (rawFrom is Map) fromUser = rawFrom;

    final from = json['from_user_id']?.toString() ??
        json['fromUserId']?.toString() ??
        fromUser?['id']?.toString() ??
        '';
    final to = json['to_user_id']?.toString() ??
        json['toUserId']?.toString() ??
        (json['to_user'] is Map
            ? (json['to_user'] as Map)['id']?.toString()
            : null) ??
        (json['toUser'] is Map
            ? (json['toUser'] as Map)['id']?.toString()
            : null) ??
        '';

    final created = _parseDate(json['created_at'] ?? json['createdAt']);
    final updated =
        _parseDate(json['updated_at'] ?? json['updatedAt'] ?? created);

    return FriendRequest(
      id: id,
      fromUserId: from,
      toUserId: to,
      status: json['status']?.toString() ?? 'pending',
      createdAt: created,
      updatedAt: updated,
      fromDisplayName: fromUser?['display_name']?.toString() ??
          fromUser?['displayName']?.toString(),
      fromUsername: fromUser?['username']?.toString(),
    );
  }

  factory FriendRequest.fromJson(Map<String, dynamic> json, String id) {
    // Prefer Laravel-style keys when present.
    if (json.containsKey('from_user_id') || json.containsKey('to_user_id')) {
      return FriendRequest.fromApiJson({...json, 'id': id});
    }

    final fromUserId =
        json['fromUserId']?.toString() ?? json['from_user_id']?.toString() ?? '';
    final toUserId =
        json['toUserId']?.toString() ?? json['to_user_id']?.toString() ?? '';
    final status = json['status']?.toString() ?? 'pending';
    final createdAt = _parseDate(json['createdAt'] ?? json['created_at']);
    final updatedAt =
        _parseDate(json['updatedAt'] ?? json['updated_at'] ?? createdAt);

    if (fromUserId.isEmpty || toUserId.isEmpty) {
      throw Exception('Failed to parse friend request. JSON: $json');
    }

    return FriendRequest(
      id: id,
      fromUserId: fromUserId,
      toUserId: toUserId,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  String get fromLabel {
    if (fromDisplayName != null && fromDisplayName!.trim().isNotEmpty) {
      return fromDisplayName!.trim();
    }
    if (fromUsername != null && fromUsername!.trim().isNotEmpty) {
      return '@${fromUsername!.trim()}';
    }
    return 'Unknown User';
  }

  Map<String, dynamic> toJson() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  FriendRequest copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? fromDisplayName,
    String? fromUsername,
  }) {
    return FriendRequest(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fromDisplayName: fromDisplayName ?? this.fromDisplayName,
      fromUsername: fromUsername ?? this.fromUsername,
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isCanceled => status == 'canceled';
}

/// Friend relationship model
class Friend {
  final String id;
  final String friendId;
  final DateTime createdAt;

  Friend({
    required this.id,
    required this.friendId,
    required this.createdAt,
  });

  factory Friend.fromJson(Map<String, dynamic> json, String id) {
    return Friend(
      id: id,
      friendId: json['friend_id']?.toString() ??
          json['friendId']?.toString() ??
          id,
      createdAt: FriendRequest._parseDate(
        json['created_at'] ?? json['createdAt'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'friendId': friendId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
