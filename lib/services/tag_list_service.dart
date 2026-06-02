import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/tag_lists.dart';

/// Service to fetch and cache tag lists from Firestore config/tagLists
class TagListService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
      final doc = await _firestore.collection('config').doc('tagLists').get();

      if (!doc.exists) {
        debugPrint('⚠️ Tag lists document not found. Using default values.');
        return _getDefaultTagLists();
      }

      _cachedTagLists = TagLists.fromJson(doc.data()!);
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

  /// Listen to tag lists changes (optional - for real-time updates)
  static Stream<TagLists> watchTagLists() {
    return _firestore
        .collection('config')
        .doc('tagLists')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return _getDefaultTagLists();
      }
      _cachedTagLists = TagLists.fromJson(snapshot.data()!);
      _lastFetchTime = DateTime.now();
      return _cachedTagLists!;
    });
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

  /// Add a new cloth type to Firestore (syncs across all users)
  /// Authenticated users can add new types discovered by AI detection
  static Future<void> addClothType(String clothType) async {
    try {
      final tags = getCachedTagLists();
      if (tags.clothTypes.contains(clothType)) {
        return; // Already exists
      }

      // Update local cache first
      final updatedTypes = List<String>.from(tags.clothTypes)..add(clothType);
      _cachedTagLists = tags.copyWith(clothTypes: updatedTypes);

      // Update Firestore using arrayUnion (adds only if not exists)
      await _firestore.collection('config').doc('tagLists').update({
        'clothTypes': FieldValue.arrayUnion([clothType]),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Added new cloth type: $clothType');
    } catch (e) {
      debugPrint('❌ Error adding cloth type: $e');
      // Revert local cache on error
      _cachedTagLists = getCachedTagLists();
    }
  }

  /// Add new colors to Firestore (syncs across all users)
  /// Authenticated users can add new colors discovered by AI detection
  static Future<void> addColors(List<String> colors) async {
    try {
      final tags = getCachedTagLists();
      final newColors = <String>[];

      for (final color in colors) {
        if (!tags.commonColors.contains(color)) {
          newColors.add(color);
        }
      }

      if (newColors.isEmpty) {
        return; // All colors already exist
      }

      // Update local cache first
      final updatedColors = List<String>.from(tags.commonColors)..addAll(newColors);
      _cachedTagLists = tags.copyWith(commonColors: updatedColors);

      // Update Firestore using arrayUnion (adds only if not exists)
      await _firestore.collection('config').doc('tagLists').update({
        'commonColors': FieldValue.arrayUnion(newColors),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Added new colors: $newColors');
    } catch (e) {
      debugPrint('❌ Error adding colors: $e');
      // Revert local cache on error
      _cachedTagLists = getCachedTagLists();
    }
  }
}

