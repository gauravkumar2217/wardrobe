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
    return Chat(
      id: id,
      participants: List<String>.from(json['participants']),
      lastMessage: json['lastMessage'] as String?,
      lastMessageAt: json['lastMessageAt'] != null
          ? (json['lastMessageAt'] as Timestamp).toDate()
          : null,
      isGroup: json['isGroup'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
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
  final DateTime createdAt;
  final List<String> seenBy;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.text,
    this.imageUrl,
    this.clothId,
    required this.createdAt,
    List<String>? seenBy,
  }) : seenBy = seenBy ?? [];

  factory ChatMessage.fromJson(Map<String, dynamic> json, String id) {
    return ChatMessage(
      id: id,
      senderId: json['senderId'] as String,
      text: json['text'] as String?,
      imageUrl: json['imageUrl'] as String?,
      clothId: json['clothId'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      seenBy: json['seenBy'] != null
          ? List<String>.from(json['seenBy'])
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      if (text != null) 'text': text,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (clothId != null) 'clothId': clothId,
      'createdAt': Timestamp.fromDate(createdAt),
      'seenBy': seenBy,
    };
  }

  bool get isText => text != null && text!.isNotEmpty;
  bool get isImage => imageUrl != null;
  bool get isClothShare => clothId != null;
  bool isSeenBy(String userId) => seenBy.contains(userId);
}

