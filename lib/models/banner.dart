/// Banner model for displaying advertisements
class Banner {
  final int id;
  final String type;
  final String imageUrl;
  final String? altTag;
  final String displayLocation;
  final String? expireDate;
  final int sortOrder;

  Banner({
    required this.id,
    required this.type,
    required this.imageUrl,
    this.altTag,
    required this.displayLocation,
    this.expireDate,
    required this.sortOrder,
  });

  factory Banner.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      final s = v.toString().trim();
      return int.tryParse(s) ?? fallback;
    }

    return Banner(
      id: parseInt(json['id']),
      type: (json['type'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      altTag: json['alt_tag'] as String?,
      displayLocation: (json['display_location'] ?? '').toString(),
      expireDate: json['expire_date'] as String?,
      sortOrder: parseInt(json['sort_order']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'image_url': imageUrl,
      'alt_tag': altTag,
      'display_location': displayLocation,
      'expire_date': expireDate,
      'sort_order': sortOrder,
    };
  }
}
