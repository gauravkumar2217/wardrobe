import '../models/cloth.dart';

/// Outfit slot keys used by the changing room and Laravel try-on API.
class TryOnCategory {
  TryOnCategory._();

  static const List<String> slotOrder = [
    'shirt',
    'pants',
    'shoes',
    'accessory',
  ];

  static const List<String> _tops = [
    'shirt',
    't-shirt',
    'tshirt',
    'top',
    'blouse',
    'sweater',
    'hoodie',
    'dress',
    'gown',
    'jumpsuit',
    'romper',
    'jacket',
    'coat',
    'blazer',
    'cardigan',
    'vest',
    'kurta',
    'tank',
    'polo',
    'tunic',
    'crop top',
    'camisole',
    'tee',
  ];

  static const List<String> _bottoms = [
    'pants',
    'pant',
    'pent',
    'trousers',
    'jeans',
    'shorts',
    'leggings',
    'skirt',
    'cargo',
    'chinos',
    'joggers',
    'palazzos',
    'culottes',
    'bottom',
  ];

  static const List<String> _shoes = [
    'shoes',
    'shoe',
    'sneakers',
    'sneaker',
    'boots',
    'boot',
    'sandals',
    'sandal',
    'heels',
    'footwear',
    'loafers',
    'flats',
    'oxfords',
    'slippers',
    'mules',
  ];

  static const List<String> _accessories = [
    'accessory',
    'accessories',
    'bag',
    'hat',
    'watch',
    'jewelry',
    'belt',
    'scarf',
    'sunglasses',
    'tie',
    'necklace',
    'bracelet',
    'earrings',
    'ring',
    'cap',
    'purse',
    'clutch',
    'backpack',
    'handbag',
  ];

  static bool _matchesAny(String type, List<String> keywords) {
    final t = type.toLowerCase();
    return keywords.any((k) => t.contains(k));
  }

  static String slotForType(String clothType) {
    final t = clothType.toLowerCase().trim();
    if (slotOrder.contains(t)) return t;
    if (_matchesAny(t, _tops)) return 'shirt';
    if (_matchesAny(t, _bottoms)) return 'pants';
    if (_matchesAny(t, _shoes)) return 'shoes';
    if (_matchesAny(t, _accessories)) return 'accessory';
    return 'shirt';
  }

  static String slotForCloth(Cloth cloth) {
    final kind = cloth.itemKind.toLowerCase();
    if (kind == 'footwear') return 'shoes';
    if (kind == 'accessories') return 'accessory';
    return slotForType(cloth.clothType);
  }

  static bool isTop(String type) => _matchesAny(type, _tops);
  static bool isBottom(String type) => _matchesAny(type, _bottoms);
  static bool isShoes(String type) => _matchesAny(type, _shoes);
  static bool isAccessory(String type) => _matchesAny(type, _accessories);

  static bool isTryOnEligible(Cloth cloth) {
    final kind = cloth.itemKind.toLowerCase();
    return kind == 'cloth' || kind == 'footwear' || kind == 'accessories';
  }
}
