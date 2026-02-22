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
    return Banner(
      id: json['id'] as int,
      type: json['type'] as String,
      imageUrl: json['image_url'] as String,
      altTag: json['alt_tag'] as String?,
      displayLocation: json['display_location'] as String,
      expireDate: json['expire_date'] as String?,
      sortOrder: json['sort_order'] as int,
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
