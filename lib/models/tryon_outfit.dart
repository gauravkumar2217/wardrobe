import '../models/cloth.dart';

/// Current outfit being tried on in the changing room
class TryOnOutfit {
  final String? shirtId;
  final String? pantsId;
  final String? shoesId;
  final String? accessoryId;
  final Map<String, Cloth?> items; // Map of item type to Cloth object

  TryOnOutfit({
    this.shirtId,
    this.pantsId,
    this.shoesId,
    this.accessoryId,
    Map<String, Cloth?>? items,
  }) : items = items ?? {};

  /// Get cloth by type
  Cloth? getClothByType(String type) {
    return items[type];
  }

  /// Update item in outfit
  TryOnOutfit copyWith({
    String? shirtId,
    String? pantsId,
    String? shoesId,
    String? accessoryId,
    Map<String, Cloth?>? items,
  }) {
    return TryOnOutfit(
      shirtId: shirtId ?? this.shirtId,
      pantsId: pantsId ?? this.pantsId,
      shoesId: shoesId ?? this.shoesId,
      accessoryId: accessoryId ?? this.accessoryId,
      items: items ?? Map.from(this.items),
    );
  }

  /// Check if outfit has any items
  bool get hasItems {
    return shirtId != null ||
        pantsId != null ||
        shoesId != null ||
        accessoryId != null;
  }
}
