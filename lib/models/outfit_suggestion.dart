/// Model for outfit suggestions
class OutfitSuggestion {
  final String id;
  final String userId;
  final DateTime createdAt;
  final List<String> clothIds; // IDs of clothes in this outfit
  final String? title;
  final String? description;
  final Map<String, dynamic> metadata; // Additional data (season, occasion, etc.)

  OutfitSuggestion({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.clothIds,
    this.title,
    this.description,
    this.metadata = const {},
  });

  factory OutfitSuggestion.fromJson(Map<String, dynamic> json) {
    return OutfitSuggestion(
      id: json['id'] as String,
      userId: json['userId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      clothIds: List<String>.from(json['clothIds'] as List),
      title: json['title'] as String?,
      description: json['description'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'clothIds': clothIds,
      'title': title,
      'description': description,
      'metadata': metadata,
    };
  }
}

