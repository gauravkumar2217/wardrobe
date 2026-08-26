import 'package:cloud_firestore/cloud_firestore.dart';

/// Notification model
class AppNotification {
  final String id;
  final String type; // "friend_request", "friend_accept", "dm_message", "cloth_like", "cloth_comment", "suggestion"
  final String title;
  final String body;
  final Map<String, dynamic>? data; // Contains relevant IDs like clothId, chatId, userId
  final DateTime createdAt;
  final bool read;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.createdAt,
    this.read = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json, String id) {
    return AppNotification(
      id: id,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'])
          : null,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      read: json['read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'body': body,
      if (data != null) 'data': data,
      'createdAt': Timestamp.fromDate(createdAt),
      'read': read,
    };
  }

  AppNotification copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    bool? read,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
    );
  }

  // Helper getters for common data fields (supports camelCase + snake_case)
  String? get clothId =>
      (data?['clothId'] ?? data?['cloth_id'])?.toString();
  String? get chatId =>
      (data?['chatId'] ?? data?['chat_id'])?.toString();
  String? get userId =>
      (data?['userId'] ?? data?['user_id'] ?? data?['from_user_id'])
          ?.toString();
  String? get requestId =>
      (data?['requestId'] ?? data?['request_id'])?.toString();
  String? get messageId =>
      (data?['messageId'] ?? data?['message_id'])?.toString();
  String? get likeId => (data?['likeId'] ?? data?['like_id'])?.toString();
  String? get commentId =>
      (data?['commentId'] ?? data?['comment_id'])?.toString();
}

