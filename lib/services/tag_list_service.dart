import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/tag_lists.dart';
import 'laravel_api_client.dart';

/// Service to fetch and cache tag lists from Laravel API.
class TagListService {
  static TagLists? _cachedTagLists;
  static DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(hours: 24);

  /// Fetch tag lists from Firestore
  /// Caches the result locally for offline access
  static Future<TagLists> fetchTagLists({bool forceRefresh = false}) async {
    // Return cached data if still valid and not forcing refresh
    if (!forceRefresh &&
        _cachedTagLists != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return _cachedTagLists!;
    }

    try {
      final body = await LaravelApiClient.getPublicJson(ApiConfig.configTagLists);
      final data = LaravelApiClient.extractData(body);
      if (data is! Map<String, dynamic>) {
        debugPrint('⚠️ Tag lists response invalid. Using default values.');
        return _getDefaultTagLists();
      }

      _cachedTagLists = TagLists.fromJson(data);
      _lastFetchTime = DateTime.now();

      if (kDebugMode) {
        debugPrint('✅ Tag lists fetched successfully');
        debugPrint('   Seasons: ${_cachedTagLists!.seasons.length}');
        debugPrint('   Placements: ${_cachedTagLists!.placements.length}');
        debugPrint('   Cloth Types: ${_cachedTagLists!.clothTypes.length}');
        debugPrint('   Occasions: ${_cachedTagLists!.occasions.length}');
        debugPrint('   Categories: ${_cachedTagLists!.categories.length}');
        debugPrint('   Common Colors: ${_cachedTagLists!.commonColors.length}');
        debugPrint('   Makeup Types: ${_cachedTagLists!.makeupTypes.length}');
        debugPrint('   Footwear Types: ${_cachedTagLists!.footwearTypes.length}');
        debugPrint('   Accessory Types: ${_cachedTagLists!.accessoryTypes.length}');
        debugPrint('   Version: ${_cachedTagLists!.version}');
        if (_cachedTagLists!.lastUpdated != null) {
          debugPrint('   Last Updated: ${_cachedTagLists!.lastUpdated}');
        }
      }

      return _cachedTagLists!;
    } catch (e) {
      debugPrint('❌ Error fetching tag lists: $e');
      // Return cached data if available, otherwise return defaults
      return _cachedTagLists ?? _getDefaultTagLists();
    }
  }

  /// Get cached tag lists (returns defaults if not cached)
  static TagLists getCachedTagLists() {
    return _cachedTagLists ?? _getDefaultTagLists();
  }

  /// Clear cache (force refresh on next fetch)
  static void clearCache() {
    _cachedTagLists = null;
    _lastFetchTime = null;
  }

  /// Poll tag lists periodically (replaces Firestore real-time stream).
  static Stream<TagLists> watchTagLists() async* {
    yield await fetchTagLists();
    while (true) {
      await Future.delayed(const Duration(hours: 1));
      yield await fetchTagLists(forceRefresh: true);
    }
  }

  /// Default tag lists (fallback if Firestore document doesn't exist)
  static TagLists _getDefaultTagLists() {
    return TagLists(
      seasons: [
        'Summer',
        'Winter',
        'Rainy',
        'All Season',
        'Spring',
        'Fall',
        'Monsoon',
      ],
      placements: [
        'InWardrobe',
        'OutWardrobe',
        'DryCleaning',
        'Repairing',
        'Laundry',
        'Storage',
        'Donated',
        'Sold',
        'Lent',
      ],
      clothTypes: [
        'Saree',
        'Kurta',
        'Lehenga',
        'Anarkali',
        'Sherwani',
        'Dhoti',
        'Kurta Pajama',
        'Blazer',
        'Jeans',
        'Suit',
        'Shirt',
        'T-Shirt',
        'Dress',
        'Pants',
        'Skirt',
        'Shorts',
        'Jacket',
        'Coat',
        'Sweater',
        'Blouse',
        'Top',
        'Trouser',
        'Jumpsuit',
        'Palazzo',
        'Churidar',
        'Salwar',
        'Dupatta',
        'Waistcoat',
      ],
      occasions: [
        'Diwali',
        'Eid',
        'Baisakhi',
        'Holi',
        'Onam',
        'Pongal',
        'Durga Puja',
        'Navratri',
        'Raksha Bandhan',
        'Karva Chauth',
        'Christmas',
        'New Year',
        'Easter',
        'Thanksgiving',
        "Valentine's Day",
        'Wedding',
        'Birthday',
        'Anniversary',
        'Engagement',
        'Reception',
        'Casual',
        'Formal',
        'Party',
        'Office',
        'Travel',
        'Sports',
        'Gym',
        'Beach',
        'Dinner',
        'Lunch',
        'Brunch',
        'Cocktail',
        'Festival',
        'Religious',
        'Cultural',
      ],
      categories: [
        'Ethnic',
        'Western',
        'Office',
        'Casual',
        'Festive',
        'Wedding',
        'Sports',
        'Nighty',
        'Party',
        'Travel',
        'Formal',
        'Traditional',
        'Contemporary',
        'Fusion',
        'Vintage',
        'Designer',
        'Streetwear',
        'Athletic',
        'Beachwear',
        'Loungewear',
      ],
      commonColors: [
        'Red',
        'Blue',
        'Green',
        'Black',
        'White',
        'Yellow',
        'Pink',
        'Orange',
        'Purple',
        'Brown',
        'Grey',
        'Navy',
        'Maroon',
        'Beige',
        'Cream',
        'Gold',
        'Silver',
        'Turquoise',
        'Coral',
        'Lavender',
        'Teal',
        'Burgundy',
        'Magenta',
        'Cyan',
        'Olive',
        'Khaki',
        'Indigo',
        'Violet',
        'Peach',
        'Mint',
      ],
      makeupTypes: [
        'Lipstick',
        'Foundation',
        'Blush',
        'Eyeshadow',
        'Mascara',
        'Eyeliner',
        'Concealer',
        'Highlighter',
        'Bronzer',
        'Setting Powder',
        'Lip Gloss',
        'Kajal',
        'Primer',
        'BB Cream',
        'Nail Polish',
      ],
      footwearTypes: [
        'Sneakers',
        'Heels',
        'Sandals',
        'Boots',
        'Flats',
        'Loafers',
        'Oxfords',
        'Flip-Flops',
        'Wedges',
        'Ankle Boots',
        'Sports Shoes',
        'Formal Shoes',
        'Slippers',
        'Jutti',
        'Kolhapuri',
      ],
      accessoryTypes: [
        'Watch',
        'Belt',
        'Bag',
        'Sunglasses',
        'Scarf',
        'Hat',
        'Cap',
        'Necklace',
        'Earrings',
        'Bracelet',
        'Ring',
        'Hair Clip',
        'Wallet',
        'Tie',
        'Pocket Square',
      ],
      version: 1,
    );
  }

  // Getters for easy access to cached lists
  static List<String> get seasons => getCachedTagLists().seasons;
  static List<String> get placements => getCachedTagLists().placements;
  static List<String> get clothTypes => getCachedTagLists().clothTypes;
  static List<String> get occasions => getCachedTagLists().occasions;
  static List<String> get categories => getCachedTagLists().categories;
  static List<String> get commonColors => getCachedTagLists().commonColors;
  static List<String> get makeupTypes => getCachedTagLists().makeupTypes;
  static List<String> get footwearTypes => getCachedTagLists().footwearTypes;
  static List<String> get accessoryTypes => getCachedTagLists().accessoryTypes;

  /// Add a new cloth type to local cache (server config managed via Laravel admin).
  static Future<void> addClothType(String clothType) async {
    final tags = getCachedTagLists();
    if (tags.clothTypes.contains(clothType)) return;
    final updatedTypes = List<String>.from(tags.clothTypes)..add(clothType);
    _cachedTagLists = tags.copyWith(clothTypes: updatedTypes);
    debugPrint('Added cloth type to local cache: $clothType');
  }

  /// Add new colors to local cache (server config managed via Laravel admin).
  static Future<void> addColors(List<String> colors) async {
    final tags = getCachedTagLists();
    final newColors =
        colors.where((c) => !tags.commonColors.contains(c)).toList();
    if (newColors.isEmpty) return;
    final updatedColors = List<String>.from(tags.commonColors)..addAll(newColors);
    _cachedTagLists = tags.copyWith(commonColors: updatedColors);
    debugPrint('Added colors to local cache: $newColors');
  }
}

