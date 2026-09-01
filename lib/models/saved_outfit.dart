import '../utils/outfit_slots.dart';
import '../utils/outfit_planner_days.dart';
import '../utils/cloth_image_url.dart';

/// A user-saved outfit combo (Outfit Generator collection).
class SavedOutfit {
  final String id;
  final String userId;
  final String name;
  final String? plannedDay;
  final Map<String, String?> slots;
  final Map<String, SavedOutfitSlotItem?> slotItems;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SavedOutfit({
    required this.id,
    required this.userId,
    required this.name,
    this.plannedDay,
    required this.slots,
    this.slotItems = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory SavedOutfit.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic raw) {
      if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
      return null;
    }

    final rawSlots = json['slots'];
    final slots = <String, String?>{};
    if (rawSlots is Map) {
      for (final key in OutfitSlots.all) {
        final v = rawSlots[key];
        slots[key] = v == null ? null : v.toString();
      }
    } else {
      slots.addAll(OutfitSlots.empty());
    }

    final rawItems = json['slot_items'] ?? json['slotItems'];
    final slotItems = <String, SavedOutfitSlotItem?>{};
    if (rawItems is Map) {
      for (final key in OutfitSlots.all) {
        final v = rawItems[key];
        slotItems[key] = v is Map
            ? SavedOutfitSlotItem.fromJson(Map<String, dynamic>.from(v))
            : null;
      }
    }

    return SavedOutfit(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'My outfit',
      plannedDay: json['planned_day']?.toString() ?? json['plannedDay']?.toString(),
      slots: slots,
      slotItems: slotItems,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDate(json['updated_at'] ?? json['updatedAt']),
    );
  }

  int get itemCount =>
      slots.values.where((id) => id != null && id.isNotEmpty).length;

  String? get previewImageUrl {
    const order = ['top', 'bottom', 'footwear', 'accessories', 'makeup'];
    for (final key in order) {
      final item = slotItems[key];
      if (item == null) continue;
      final url = item.displayImageUrl;
      if (url.isNotEmpty) return url;
    }
    return null;
  }

  /// Build Mon–Sun planner rows from saved collections.
  static List<({String dayKey, String dayLabel, SavedOutfit? outfit})> weekPlan(
    List<SavedOutfit> saved,
  ) {
    final byDay = <String, SavedOutfit>{};
    final unassigned = <SavedOutfit>[];

    for (final outfit in saved) {
      final day = outfit.plannedDay?.toLowerCase().trim();
      if (day != null &&
          day.isNotEmpty &&
          OutfitPlannerDays.keys.contains(day) &&
          !byDay.containsKey(day)) {
        byDay[day] = outfit;
      } else {
        unassigned.add(outfit);
      }
    }

    unassigned.sort((a, b) {
      final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ad.compareTo(bd);
    });

    var spare = 0;
    return OutfitPlannerDays.keys.map((key) {
      SavedOutfit? outfit = byDay[key];
      if (outfit == null && spare < unassigned.length) {
        outfit = unassigned[spare++];
      }
      return (
        dayKey: key,
        dayLabel: OutfitPlannerDays.labels[key] ?? key,
        outfit: outfit,
      );
    }).toList();
  }
}

class SavedOutfitSlotItem {
  final String id;
  final String clothType;
  final String category;
  final String imageUrl;
  final String? processedImageUrl;

  SavedOutfitSlotItem({
    required this.id,
    required this.clothType,
    required this.category,
    required this.imageUrl,
    this.processedImageUrl,
  });

  factory SavedOutfitSlotItem.fromJson(Map<String, dynamic> json) {
    return SavedOutfitSlotItem(
      id: json['id']?.toString() ?? '',
      clothType: json['cloth_type']?.toString() ??
          json['clothType']?.toString() ??
          'Item',
      category: json['category']?.toString() ?? '',
      imageUrl:
          json['image_url']?.toString() ?? json['imageUrl']?.toString() ?? '',
      processedImageUrl: json['processed_image_url']?.toString() ??
          json['processedImageUrl']?.toString(),
    );
  }

  String get displayImageUrl {
    final processed = processedImageUrl?.trim();
    if (processed != null && processed.isNotEmpty) {
      final resolved = ClothImageUrl.resolve(processed);
      if (resolved.isNotEmpty) return resolved;
    }
    return ClothImageUrl.resolve(imageUrl);
  }
}
