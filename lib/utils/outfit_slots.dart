/// Outfit combo slot keys used by Outfit Generator and saved outfits API.
class OutfitSlots {
  OutfitSlots._();

  static const all = ['top', 'bottom', 'footwear', 'accessories', 'makeup'];

  static const labels = {
    'top': 'Top',
    'bottom': 'Bottom',
    'footwear': 'Footwear',
    'accessories': 'Accessories',
    'makeup': 'Beauty',
  };

  static Map<String, String?> empty() {
    return {for (final k in all) k: null};
  }
}
