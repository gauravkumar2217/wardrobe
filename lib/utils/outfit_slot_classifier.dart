import '../models/cloth.dart';
import 'outfit_slots.dart';

/// Maps wardrobe items to outfit combo slots (top, bottom, footwear, etc.).
class OutfitSlotClassifier {
  static bool isTopType(String type) {
    final t = type.toLowerCase();
    return [
      'shirt',
      't-shirt',
      'top',
      'blouse',
      'sweater',
      'hoodie',
      'dress',
      'jacket',
      'coat',
      'blazer',
      'cardigan',
      'vest',
      'kurta',
      'tank',
      'polo',
      'kurti',
      'saree blouse',
    ].any((k) => t.contains(k));
  }

  static bool isBottomType(String type) {
    final t = type.toLowerCase();
    return [
      'pants',
      'trousers',
      'jeans',
      'shorts',
      'leggings',
      'skirt',
      'cargo',
      'salwar',
      'churidar',
    ].any((k) => t.contains(k));
  }

  static bool isFootwearType(String type, {String itemKind = 'cloth'}) {
    if (itemKind == 'footwear') return true;
    final t = type.toLowerCase();
    return [
      'shoes',
      'sneakers',
      'boots',
      'sandals',
      'heels',
      'footwear',
      'loafers',
      'flats',
      'jutti',
    ].any((k) => t.contains(k));
  }

  static bool isAccessoryType(String type, {String itemKind = 'cloth'}) {
    if (itemKind == 'accessories') return true;
    final t = type.toLowerCase();
    return [
      'accessory',
      'bag',
      'hat',
      'watch',
      'jewelry',
      'belt',
      'scarf',
      'sunglasses',
      'handbag',
    ].any((k) => t.contains(k));
  }

  static bool isMakeupType(String type, {String itemKind = 'cloth'}) {
    if (itemKind == 'makeup') return true;
    final t = type.toLowerCase();
    return [
      'lipstick',
      'kajal',
      'makeup',
      'beauty',
      'foundation',
      'mascara',
      'eyeliner',
    ].any((k) => t.contains(k));
  }

  /// Primary slot for an item; clothing defaults to top if ambiguous.
  static String slotFor(Cloth cloth) {
    final kind = cloth.itemKind.toLowerCase();
    if (kind == 'makeup' || isMakeupType(cloth.clothType, itemKind: kind)) {
      return 'makeup';
    }
    if (kind == 'footwear' || isFootwearType(cloth.clothType, itemKind: kind)) {
      return 'footwear';
    }
    if (kind == 'accessories' ||
        isAccessoryType(cloth.clothType, itemKind: kind)) {
      return 'accessories';
    }
    if (isBottomType(cloth.clothType)) return 'bottom';
    if (isTopType(cloth.clothType)) return 'top';
    return 'top';
  }

  static List<Cloth> filterForSlot(List<Cloth> all, String slotKey) {
    return all.where((c) => slotFor(c) == slotKey).toList();
  }
}
