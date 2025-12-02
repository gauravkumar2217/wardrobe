import 'package:cloud_firestore/cloud_firestore.dart';

/// Friend Request model
class FriendRequest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String status; // "pending", "accepted", "rejected", "canceled"
  final DateTime createdAt;
  final DateTime updatedAt;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json, String id) {
    try {
      final fromUserId = json['fromUserId'] as String?;
      final toUserId = json['toUserId'] as String?;
      final status = json['status'] as String?;
      final createdAt = json['createdAt'] as Timestamp?;
      final updatedAt = json['updatedAt'] as Timestamp?;

      if (fromUserId == null || fromUserId.isEmpty) {
        throw Exception('fromUserId is missing or empty');
      }
      if (toUserId == null || toUserId.isEmpty) {
        throw Exception('toUserId is missing or empty');
      }
      if (status == null || status.isEmpty) {
        throw Exception('status is missing or empty');
      }
      if (createdAt == null) {
        throw Exception('createdAt is missing');
      }
      if (updatedAt == null) {
        throw Exception('updatedAt is missing');
      }

      return FriendRequest(
        id: id,
        fromUserId: fromUserId,
        toUserId: toUserId,
        status: status,
        createdAt: createdAt.toDate(),
        updatedAt: updatedAt.toDate(),
      );
    } catch (e) {
      throw Exception('Failed to parse friend request: $e. JSON: $json');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  FriendRequest copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FriendRequest(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isCanceled => status == 'canceled';
}

/// Friend relationship model
class Friend {
  final String id; // friendId
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
      friendId: json['friendId'] as String? ?? id,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'friendId': friendId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

