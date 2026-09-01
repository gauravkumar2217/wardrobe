import '../models/cloth.dart';
import 'try_on_category.dart';

/// Maps wardrobe items to outfit combo slots (top, bottom, footwear, etc.).
class OutfitSlotClassifier {
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

  /// Primary slot for an item; aligned with try-on categories.
  static String slotFor(Cloth cloth) {
    final kind = cloth.itemKind.toLowerCase();
    if (kind == 'makeup' || isMakeupType(cloth.clothType, itemKind: kind)) {
      return 'makeup';
    }
    if (kind == 'footwear') return 'footwear';
    if (kind == 'accessories') return 'accessories';

    switch (TryOnCategory.slotForCloth(cloth)) {
      case 'pants':
        return 'bottom';
      case 'shoes':
        return 'footwear';
      case 'accessory':
        return 'accessories';
      case 'shirt':
      default:
        return 'top';
    }
  }

  static List<Cloth> filterForSlot(List<Cloth> all, String slotKey) {
    return all.where((c) => slotFor(c) == slotKey).toList();
  }
}
