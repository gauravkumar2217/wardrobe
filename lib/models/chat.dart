import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat model
class Chat {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool isGroup;
  final DateTime createdAt;

  Chat({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageAt,
    this.isGroup = false,
    required this.createdAt,
  });

  factory Chat.fromJson(Map<String, dynamic> json, String id) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    return Chat(
      id: id,
      participants: List<String>.from(json['participants'] ?? []),
      lastMessage:
          json['last_message'] as String? ?? json['lastMessage'] as String?,
      lastMessageAt: parseDate(json['last_message_at'] ?? json['lastMessageAt']),
      isGroup: json['is_group'] as bool? ?? json['isGroup'] as bool? ?? false,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']) ??
          DateTime.now(),
    );
  }

  factory Chat.fromApiJson(Map<String, dynamic> json) {
    return Chat.fromJson(json, json['id']?.toString() ?? '');
  }

  Map<String, dynamic> toJson() {
    return {
      'participants': participants,
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastMessageAt != null)
        'lastMessageAt': Timestamp.fromDate(lastMessageAt!),
      'isGroup': isGroup,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Chat copyWith({
    String? id,
    List<String>? participants,
    String? lastMessage,
    DateTime? lastMessageAt,
    bool? isGroup,
    DateTime? createdAt,
  }) {
    return Chat(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      isGroup: isGroup ?? this.isGroup,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String? getOtherParticipant(String currentUserId) {
    if (participants.length == 2) {
      return participants.firstWhere((id) => id != currentUserId);
    }
    return null;
  }
}

/// Chat message model
class ChatMessage {
  final String id;
  final String senderId;
  final String? text;
  final String? imageUrl;
  final String? clothId; // When sharing a cloth
  final String? clothOwnerId; // Owner of the shared cloth
  final String? clothWardrobeId; // Wardrobe ID of the shared cloth
  final DateTime createdAt;
  final List<String> seenBy;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.text,
    this.imageUrl,
    this.clothId,
    this.clothOwnerId,
    this.clothWardrobeId,
    required this.createdAt,
    List<String>? seenBy,
  }) : seenBy = seenBy ?? [];

  factory ChatMessage.fromJson(Map<String, dynamic> json, String id) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return ChatMessage(
      id: id,
      senderId:
          json['sender_id'] as String? ?? json['senderId'] as String? ?? '',
      text: json['text'] as String?,
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
      clothId: json['cloth_id'] as String? ?? json['clothId'] as String?,
      clothOwnerId: json['cloth_owner_id'] as String? ??
          json['clothOwnerId'] as String?,
      clothWardrobeId: json['cloth_wardrobe_id'] as String? ??
          json['clothWardrobeId'] as String?,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      seenBy: json['seen_by'] != null
          ? List<String>.from(json['seen_by'])
          : json['seenBy'] != null
              ? List<String>.from(json['seenBy'])
              : [],
    );
  }

  factory ChatMessage.fromApiJson(Map<String, dynamic> json) {
    return ChatMessage.fromJson(json, json['id']?.toString() ?? '');
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      if (text != null) 'text': text,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (clothId != null) 'clothId': clothId,
      if (clothOwnerId != null) 'clothOwnerId': clothOwnerId,
      if (clothWardrobeId != null) 'clothWardrobeId': clothWardrobeId,
      'createdAt': Timestamp.fromDate(createdAt),
      'seenBy': seenBy,
    };
  }

  bool get isText => text != null && text!.isNotEmpty;
  bool get isImage => imageUrl != null;
  bool get isClothShare => clothId != null;
  bool isSeenBy(String userId) => seenBy.contains(userId);
}

