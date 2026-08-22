/// User-planned event with occasion-based outfit suggestions.
class PlannedEvent {
  final String id;
  final String userId;
  final String title;
  final String occasionTag;
  final DateTime eventAt;
  final String? location;
  final String? notes;
  final int reminderHoursBefore;
  final DateTime? reminderSentAt;
  final List<String> suggestedClothIds;
  final List<EventClothSuggestion> suggestions;
  final DateTime? createdAt;

  PlannedEvent({
    required this.id,
    required this.userId,
    required this.title,
    required this.occasionTag,
    required this.eventAt,
    this.location,
    this.notes,
    this.reminderHoursBefore = 24,
    this.reminderSentAt,
    this.suggestedClothIds = const [],
    this.suggestions = const [],
    this.createdAt,
  });

  factory PlannedEvent.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic raw) {
      if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
      return null;
    }

    final rawSuggestions = json['suggestions'];
    final suggestions = rawSuggestions is List
        ? rawSuggestions
            .whereType<Map>()
            .map((e) => EventClothSuggestion.fromJson(
                Map<String, dynamic>.from(e)))
            .toList()
        : <EventClothSuggestion>[];

    final rawIds = json['suggested_cloth_ids'] ?? json['suggestedClothIds'];
    final ids = rawIds is List
        ? rawIds.map((e) => e.toString()).toList()
        : <String>[];

    return PlannedEvent(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Event',
      occasionTag:
          json['occasion_tag']?.toString() ?? json['occasionTag']?.toString() ?? '',
      eventAt: parseDate(json['event_at'] ?? json['eventAt']) ?? DateTime.now(),
      location: json['location']?.toString(),
      notes: json['notes']?.toString(),
      reminderHoursBefore:
          (json['reminder_hours_before'] as num?)?.toInt() ??
              (json['reminderHoursBefore'] as num?)?.toInt() ??
              24,
      reminderSentAt: parseDate(json['reminder_sent_at'] ?? json['reminderSentAt']),
      suggestedClothIds: ids,
      suggestions: suggestions,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
    );
  }

  String get dateLabel {
    final local = eventAt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = local.hour;
    final m = local.minute.toString().padLeft(2, '0');
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final ampm = h >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, $hour12:$m $ampm';
  }
}

class EventClothSuggestion {
  final String id;
  final String? wardrobeId;
  final String clothType;
  final String category;
  final List<String> occasions;
  final String imageUrl;
  final String? processedImageUrl;
  final int matchScore;
  final String matchReason;

  EventClothSuggestion({
    required this.id,
    this.wardrobeId,
    required this.clothType,
    required this.category,
    required this.occasions,
    required this.imageUrl,
    this.processedImageUrl,
    required this.matchScore,
    required this.matchReason,
  });

  factory EventClothSuggestion.fromJson(Map<String, dynamic> json) {
    return EventClothSuggestion(
      id: json['id']?.toString() ?? '',
      wardrobeId: json['wardrobe_id']?.toString() ??
          json['wardrobeId']?.toString(),
      clothType: json['cloth_type']?.toString() ??
          json['clothType']?.toString() ??
          'Item',
      category: json['category']?.toString() ?? '',
      occasions: json['occasions'] is List
          ? (json['occasions'] as List).map((e) => e.toString()).toList()
          : const [],
      imageUrl:
          json['image_url']?.toString() ?? json['imageUrl']?.toString() ?? '',
      processedImageUrl: json['processed_image_url']?.toString() ??
          json['processedImageUrl']?.toString(),
      matchScore: (json['match_score'] as num?)?.toInt() ??
          (json['matchScore'] as num?)?.toInt() ??
          0,
      matchReason: json['match_reason']?.toString() ??
          json['matchReason']?.toString() ??
          '',
    );
  }

  String get displayImageUrl {
    if (processedImageUrl != null && processedImageUrl!.isNotEmpty) {
      return processedImageUrl!;
    }
    return imageUrl;
  }
}
