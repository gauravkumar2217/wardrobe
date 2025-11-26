import 'package:cloud_firestore/cloud_firestore.dart';

/// Tag Lists model for dynamic tag management
/// Fetched from config/tagLists document in Firestore
class TagLists {
  final List<String> seasons;
  final List<String> placements;
  final List<String> clothTypes;
  final List<String> occasions;
  final List<String> categories;
  final List<String> commonColors;
  final DateTime? lastUpdated;
  final int version;

  TagLists({
    required this.seasons,
    required this.placements,
    required this.clothTypes,
    required this.occasions,
    required this.categories,
    required this.commonColors,
    this.lastUpdated,
    this.version = 1,
  });

  factory TagLists.fromJson(Map<String, dynamic> json) {
    return TagLists(
      seasons: List<String>.from(json['seasons'] ?? []),
      placements: List<String>.from(json['placements'] ?? []),
      clothTypes: List<String>.from(json['clothTypes'] ?? []),
      occasions: List<String>.from(json['occasions'] ?? []),
      categories: List<String>.from(json['categories'] ?? []),
      commonColors: List<String>.from(json['commonColors'] ?? []),
      lastUpdated: json['lastUpdated'] != null
          ? (json['lastUpdated'] as Timestamp).toDate()
          : null,
      version: json['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seasons': seasons,
      'placements': placements,
      'clothTypes': clothTypes,
      'occasions': occasions,
      'categories': categories,
      'commonColors': commonColors,
      'lastUpdated': lastUpdated != null
          ? Timestamp.fromDate(lastUpdated!)
          : FieldValue.serverTimestamp(),
      'version': version,
    };
  }

  TagLists copyWith({
    List<String>? seasons,
    List<String>? placements,
    List<String>? clothTypes,
    List<String>? occasions,
    List<String>? categories,
    List<String>? commonColors,
    DateTime? lastUpdated,
    int? version,
  }) {
    return TagLists(
      seasons: seasons ?? this.seasons,
      placements: placements ?? this.placements,
      clothTypes: clothTypes ?? this.clothTypes,
      occasions: occasions ?? this.occasions,
      categories: categories ?? this.categories,
      commonColors: commonColors ?? this.commonColors,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      version: version ?? this.version,
    );
  }
}

