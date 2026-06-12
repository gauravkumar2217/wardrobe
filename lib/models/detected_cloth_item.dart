/// AI-detected clothing item from a multi-item photo analysis.
class DetectedClothItem {
  final String id;
  final String name;
  final String category;
  final String subcategory;
  final String clothType;
  final String color;
  final String? material;
  final String? pattern;
  final String season;
  final String? brand;
  final String? gender;
  final List<String> styleTags;
  final String itemKind;
  final List<String> occasions;
  final double confidence;

  // Filled after extraction
  final String? imageUrl;
  final String? processedImageUrl;
  final bool hasProcessedImage;

  const DetectedClothItem({
    required this.id,
    required this.name,
    required this.category,
    required this.subcategory,
    required this.clothType,
    required this.color,
    this.material,
    this.pattern,
    this.season = 'all',
    this.brand,
    this.gender,
    this.styleTags = const [],
    this.itemKind = 'cloth',
    this.occasions = const ['Casual'],
    this.confidence = 0.5,
    this.imageUrl,
    this.processedImageUrl,
    this.hasProcessedImage = false,
  });

  factory DetectedClothItem.fromJson(Map<String, dynamic> json) {
    return DetectedClothItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Item',
      category: json['category']?.toString() ?? 'Casual',
      subcategory: json['subcategory']?.toString() ??
          json['cloth_type']?.toString() ??
          'Other',
      clothType: json['cloth_type']?.toString() ??
          json['subcategory']?.toString() ??
          'Other',
      color: json['color']?.toString() ?? 'Unknown',
      material: json['material']?.toString(),
      pattern: json['pattern']?.toString(),
      season: json['season']?.toString() ?? 'all',
      brand: json['brand']?.toString(),
      gender: json['gender']?.toString(),
      styleTags: json['style_tags'] != null
          ? List<String>.from(json['style_tags'])
          : const [],
      itemKind: json['item_kind']?.toString() ?? 'cloth',
      occasions: json['occasions'] != null
          ? List<String>.from(json['occasions'])
          : const ['Casual'],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      imageUrl: json['image_url']?.toString(),
      processedImageUrl: json['processed_image_url']?.toString(),
      hasProcessedImage: json['has_processed_image'] as bool? ?? false,
    );
  }

  DetectedClothItem copyWith({
    String? imageUrl,
    String? processedImageUrl,
    bool? hasProcessedImage,
    String? category,
    String? clothType,
    String? color,
    String? season,
    List<String>? occasions,
  }) {
    return DetectedClothItem(
      id: id,
      name: name,
      category: category ?? this.category,
      subcategory: subcategory,
      clothType: clothType ?? this.clothType,
      color: color ?? this.color,
      material: material,
      pattern: pattern,
      season: season ?? this.season,
      brand: brand,
      gender: gender,
      styleTags: styleTags,
      itemKind: itemKind,
      occasions: occasions ?? this.occasions,
      confidence: confidence,
      imageUrl: imageUrl ?? this.imageUrl,
      processedImageUrl: processedImageUrl ?? this.processedImageUrl,
      hasProcessedImage: hasProcessedImage ?? this.hasProcessedImage,
    );
  }
}
