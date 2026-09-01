import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../models/cloth.dart';
import '../models/outfit_suggestion.dart';
import '../utils/try_on_category.dart';

/// Service for generating outfit suggestions based on unworn clothes
class OutfitSuggestionService {
  static const String _suggestionsKey = 'outfit_suggestions';
  static const String _dailySuggestionKey = 'daily_outfit_suggestion';
  static const String _dailySuggestionsKey = 'daily_outfit_suggestions';
  static const int _maxStoredSuggestions = 10; // Keep last 10 suggestions
  static const int _daysNotWornThreshold = 7; // Consider "not worn recently" if not worn in 7+ days
  static const int _maxDailySuggestions = 3;

  static String _clothesFingerprint(List<Cloth> clothes) {
    final ids = clothes.map((c) => c.id).toList()..sort();
    return ids.join('|');
  }

  /// Which core outfit slots the wardrobe can fill (top, bottom, shoes).
  static Map<String, bool> outfitCoverage(List<Cloth> clothes) {
    final eligible = clothes.where(_isEligibleForSuggestion).toList();
    return {
      'top': _itemsForSlot(eligible, 'shirt').isNotEmpty,
      'bottom': _itemsForSlot(eligible, 'pants').isNotEmpty,
      'shoes': _itemsForSlot(eligible, 'shoes').isNotEmpty,
    };
  }

  static List<Cloth> orderOutfitItems(List<Cloth> items) {
    int rank(Cloth cloth) {
      final slot = TryOnCategory.slotForCloth(cloth);
      if (cloth.itemKind.toLowerCase() == 'footwear' || slot == 'shoes') {
        return 2;
      }
      if (slot == 'pants') return 1;
      if (slot == 'shirt') return 0;
      return 3;
    }

    final sorted = [...items]..sort((a, b) => rank(a).compareTo(rank(b)));
    return sorted;
  }

  static List<Cloth> _itemsForSlot(List<Cloth> eligible, String slot) {
    return eligible.where((cloth) {
      final kind = cloth.itemKind.toLowerCase();
      if (slot == 'shoes') {
        return kind == 'footwear' || TryOnCategory.slotForCloth(cloth) == 'shoes';
      }
      if (slot == 'accessory') {
        return kind == 'accessories' ||
            TryOnCategory.slotForCloth(cloth) == 'accessory';
      }
      if (kind != 'cloth') return false;
      return TryOnCategory.slotForCloth(cloth) == slot;
    }).toList();
  }

  static bool _hasMinimumOutfitCategories(List<Cloth> pool) {
    final eligible = pool.where(_isEligibleForSuggestion).toList();
    return _itemsForSlot(eligible, 'shirt').isNotEmpty &&
        _itemsForSlot(eligible, 'pants').isNotEmpty;
  }

  static String _dayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  static int _stableSeed(String input) {
    // Simple stable 32-bit hash (FNV-1a like) for deterministic daily picks.
    var hash = 0x811C9DC5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  static bool _isEligibleForSuggestion(Cloth cloth) {
    // Only suggest items that are actually wearable / available.
    // Keep this conservative so suggestions don't include donated/repair items.
    const blockedPlacements = {
      'Donated',
      'Sold',
      'Storage',
      'Repairing',
      'DryCleaning',
      'Laundry',
      'Lent',
    };
    return !blockedPlacements.contains(cloth.placement);
  }

  static int _daysSinceWorn(Cloth cloth, DateTime now) {
    if (cloth.wornAt == null) return 100000; // "Never worn" gets max priority.
    return now.difference(cloth.wornAt!).inDays;
  }

  static Set<String> _tagsFor(Cloth cloth) {
    final tags = <String>{};
    tags.add('kind:${cloth.itemKind}');
    tags.add('type:${cloth.clothType}');
    tags.add('season:${cloth.season}');
    tags.add('category:${cloth.category}');
    for (final occ in cloth.occasions) {
      tags.add('occasion:$occ');
    }
    for (final c in cloth.colorTags.colors) {
      tags.add('color:$c');
    }
    return tags;
  }

  static int _tagMatchScore(Set<String> a, Set<String> b) {
    // Weighted matching: occasion/category/season/color are more meaningful than type/kind.
    var score = 0;
    for (final tag in a) {
      if (!b.contains(tag)) continue;
      if (tag.startsWith('occasion:')) score += 5;
      else if (tag.startsWith('category:')) score += 4;
      else if (tag.startsWith('season:')) score += 3;
      else if (tag.startsWith('color:')) score += 2;
      else score += 1;
    }
    return score;
  }

  static Cloth? _pickBest({
    required List<Cloth> pool,
    required Set<String> wantedTags,
    required DateTime now,
    required Random random,
    Set<String>? excludeIds,
    String? itemKind,
    String? slot,
  }) {
    final excluded = excludeIds ?? const <String>{};
    var candidates = pool.where((c) {
      if (excluded.contains(c.id)) return false;
      if (itemKind != null && c.itemKind != itemKind) return false;
      return true;
    }).toList();

    if (slot != null) {
      candidates = _itemsForSlot(candidates, slot);
    }

    if (candidates.isEmpty) return null;

    // Score = staleness + tag match; add tiny randomness so ties rotate.
    Cloth best = candidates.first;
    var bestScore = -1.0;
    for (final c in candidates) {
      final staleness = _daysSinceWorn(c, now);
      final match = _tagMatchScore(_tagsFor(c), wantedTags);
      final jitter = random.nextDouble() * 0.25;
      final score = (staleness * 1.0) + (match * 10.0) + jitter;
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best;
  }

  static OutfitSuggestion? _buildSuggestion({
    required String userId,
    required List<Cloth> pool,
    required int index,
    required DateTime now,
    required Random random,
    String? purpose,
    String? dayKey,
    Set<String>? excludeIds,
  }) {
    if (!_hasMinimumOutfitCategories(pool)) return null;

    final alreadyUsed = excludeIds ?? const <String>{};
    final eligible = pool
        .where(_isEligibleForSuggestion)
        .where((c) => !alreadyUsed.contains(c.id))
        .toList();
    if (!_hasMinimumOutfitCategories(eligible)) return null;

    final tops = _itemsForSlot(eligible, 'shirt');
    if (tops.isEmpty) return null;

    tops.sort(
        (a, b) => _daysSinceWorn(b, now).compareTo(_daysSinceWorn(a, now)));
    final top = tops[index % tops.length];
    final wantedTags = _tagsFor(top);

    final selected = <Cloth>[top];
    final selectedIds = <String>{top.id, ...alreadyUsed};

    final bottom = _pickBest(
      pool: eligible,
      wantedTags: wantedTags,
      now: now,
      random: random,
      excludeIds: selectedIds,
      slot: 'pants',
    );
    if (bottom == null) return null;
    selected.add(bottom);
    selectedIds.add(bottom.id);

    final footwear = _pickBest(
      pool: eligible,
      wantedTags: wantedTags,
      now: now,
      random: random,
      excludeIds: selectedIds,
      slot: 'shoes',
    );
    if (footwear != null) {
      selected.add(footwear);
      selectedIds.add(footwear.id);
    }

    final accessory = _pickBest(
      pool: eligible,
      wantedTags: wantedTags,
      now: now,
      random: random,
      excludeIds: selectedIds,
      slot: 'accessory',
    );
    if (accessory != null) {
      selected.add(accessory);
      selectedIds.add(accessory.id);
    }

    final createdAt = now;
    final suggestionId = dayKey != null
        ? '${_dailySuggestionKey}_${userId}_${dayKey}_$index'
        : '${DateTime.now().millisecondsSinceEpoch}_$index';

    final anchorDays = _daysSinceWorn(top, now);
    final titleParts = <String>[];
    if (top.category.isNotEmpty) titleParts.add(top.category);
    if (top.season.isNotEmpty) titleParts.add(top.season);
    final title = titleParts.isEmpty
        ? 'Look ${index + 1}'
        : '${titleParts.join(' • ')} look';

    final occasion = top.occasions.isNotEmpty
        ? top.occasions.first
        : (top.category.isNotEmpty ? top.category : 'Everyday');

    final slotLabels = <String>['top', 'bottom'];
    if (footwear != null) slotLabels.add('shoes');
    if (accessory != null) slotLabels.add('accessory');

    final description = footwear != null
        ? 'Today’s pick: ${slotLabels.join(', ')} from your wardrobe — matched by season, occasion, and colors.'
        : 'Today’s pick: top and bottom from your wardrobe. Add shoes to complete the look.';

    // Match score: blend tag cohesion + how overdue the anchor is.
    final cohesion = selected.length <= 1
        ? 0
        : selected
            .skip(1)
            .map((c) => _tagMatchScore(_tagsFor(c), wantedTags))
            .fold<int>(0, (a, b) => a + b);
    final matchPercent =
        (78 + (cohesion.clamp(0, 18)) + (anchorDays > 7 ? 4 : 0))
            .clamp(78, 99);

    return OutfitSuggestion(
      id: suggestionId,
      userId: userId,
      createdAt: createdAt,
      clothIds: orderOutfitItems(selected).map((c) => c.id).toList(),
      title: title,
      description: description,
      metadata: {
        if (purpose != null) 'purpose': purpose,
        if (dayKey != null) 'dayKey': dayKey,
        'anchorId': top.id,
        'anchorDaysSinceWorn': anchorDays,
        'anchorCategory': top.category,
        'anchorSeason': top.season,
        'anchorOccasions': top.occasions,
        'anchorColors': top.colorTags.colors,
        'occasion': occasion,
        'matchPercent': matchPercent,
        'setIndex': index + 1,
        'includedKinds': selected.map((c) => c.itemKind).toSet().toList(),
        'includedSlots': slotLabels,
      },
    );
  }

  /// Return up to [maxSuggestions] outfits for today (stable for the day).
  /// Excludes cloths already used in earlier sets so combinations stay distinct.
  static Future<List<OutfitSuggestion>> getOrCreateDailySuggestions({
    required String userId,
    required List<Cloth> availableClothes,
    DateTime? forDate,
    int maxSuggestions = _maxDailySuggestions,
    bool forceNew = false,
  }) async {
    final date = forDate ?? DateTime.now();
    final key = _dayKey(date);
    final prefsKey = '${_dailySuggestionsKey}_${userId}_$key';
    final fingerprintKey = '${prefsKey}_fp';
    final capped = maxSuggestions.clamp(1, _maxDailySuggestions);
    final fingerprint = _clothesFingerprint(availableClothes);

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!forceNew) {
        final cached = prefs.getString(prefsKey);
        final cachedFingerprint = prefs.getString(fingerprintKey);
        if (cached != null &&
            cached.isNotEmpty &&
            cachedFingerprint == fingerprint) {
          final list = jsonDecode(cached) as List<dynamic>;
          return list
              .map((e) =>
                  OutfitSuggestion.fromJson(e as Map<String, dynamic>))
              .take(capped)
              .toList();
        }
      }

      final now = DateTime.now();
      final seed = _stableSeed('$userId-$key-sets');
      final random = Random(seed);
      final suggestions = <OutfitSuggestion>[];
      final usedIds = <String>{};

      for (var i = 0; i < capped; i++) {
        final suggestion = _buildSuggestion(
          userId: userId,
          pool: availableClothes,
          index: i,
          now: now,
          random: random,
          purpose: 'daily_suggestion',
          dayKey: key,
          excludeIds: usedIds,
        );
        if (suggestion == null) break;
        suggestions.add(suggestion);
        usedIds.addAll(suggestion.clothIds);
      }

      if (suggestions.isEmpty) return [];

      await prefs.setString(
        prefsKey,
        jsonEncode(suggestions.map((s) => s.toJson()).toList()),
      );
      await prefs.setString(fingerprintKey, fingerprint);

      // Keep the first set as the single daily cache for legacy screens.
      await prefs.setString(
        '${_dailySuggestionKey}_${userId}_$key',
        jsonEncode(suggestions.first.toJson()),
      );
      for (final s in suggestions) {
        await saveSuggestion(userId, s);
      }

      return suggestions;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to get/create daily suggestions: $e');
      }
      return [];
    }
  }

  /// Return today's suggestion (stable for the day) and cache it locally.
  /// Also stores it in the normal suggestions history so it can show up in history screens.
  static Future<OutfitSuggestion?> getOrCreateDailySuggestion({
    required String userId,
    required List<Cloth> availableClothes,
    DateTime? forDate,
    bool forceNew = false,
  }) async {
    final date = forDate ?? DateTime.now();
    final key = _dayKey(date);
    final prefsKey = '${_dailySuggestionKey}_${userId}_$key';
    final fingerprintKey = '${prefsKey}_fp';
    final fingerprint = _clothesFingerprint(availableClothes);

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!forceNew) {
        final cached = prefs.getString(prefsKey);
        final cachedFingerprint = prefs.getString(fingerprintKey);
        if (cached != null &&
            cached.isNotEmpty &&
            cachedFingerprint == fingerprint) {
          final json = jsonDecode(cached) as Map<String, dynamic>;
          return OutfitSuggestion.fromJson(json);
        }
      }

      final now = DateTime.now();
      final seed = _stableSeed('$userId-$key');
      final random = Random(seed);
      final suggestion = _buildSuggestion(
        userId: userId,
        pool: availableClothes,
        index: 0,
        now: now,
        random: random,
        purpose: 'daily_suggestion',
        dayKey: key,
      );
      if (suggestion == null) return null;

      await prefs.setString(prefsKey, jsonEncode(suggestion.toJson()));
      await prefs.setString(fingerprintKey, fingerprint);
      await saveSuggestion(userId, suggestion);
      return suggestion;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to get/create daily suggestion: $e');
      }
      return null;
    }
  }

  /// Generate outfit suggestions from unworn clothes
  /// Returns a list of outfit suggestions (each containing 2-4 clothes)
  static Future<List<OutfitSuggestion>> generateSuggestions({
    required String userId,
    required List<Cloth> availableClothes,
    int maxSuggestions = 3,
  }) async {
    if (kDebugMode) {
      debugPrint('🎨 Generating outfit suggestions...');
      debugPrint('   Available clothes: ${availableClothes.length}');
    }

    try {
      final now = DateTime.now();
      final thresholdDate = now.subtract(Duration(days: _daysNotWornThreshold));

      final eligible = availableClothes.where(_isEligibleForSuggestion).toList();

      // Filter clothes that haven't been worn recently
      final unwornClothes = eligible.where((cloth) {
        if (cloth.wornAt == null) {
          // Never worn - prioritize these
          return true;
        }
        // Worn more than threshold days ago
        return cloth.wornAt!.isBefore(thresholdDate);
      }).toList();

      if (kDebugMode) {
        debugPrint('   Unworn clothes (not worn in ${_daysNotWornThreshold}+ days): ${unwornClothes.length}');
      }

      if (unwornClothes.isEmpty) {
        if (kDebugMode) {
          debugPrint('   ⚠️ No unworn clothes found. Using all available clothes.');
        }
        // If no unworn clothes, use all available clothes
        return _generateFromAllClothes(eligible, maxSuggestions, userId);
      }

      final suggestions = <OutfitSuggestion>[];
      final random = Random();
      final usedIds = <String>{};

      // Generate suggestions
      final pool = unwornClothes.isNotEmpty ? unwornClothes : eligible;
      for (int i = 0; i < maxSuggestions; i++) {
        final suggestion = _buildSuggestion(
          userId: userId,
          pool: pool,
          index: i,
          now: now,
          random: random,
          purpose: 'scheduled_suggestion',
          excludeIds: usedIds,
        );
        if (suggestion != null) {
          suggestions.add(suggestion);
          usedIds.addAll(suggestion.clothIds);
        }
      }

      if (kDebugMode) {
        debugPrint('✅ Generated ${suggestions.length} outfit suggestions');
      }

      return suggestions;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error generating suggestions: $e');
      }
      return [];
    }
  }

  /// Generate suggestions from all clothes (fallback when no unworn clothes)
  static List<OutfitSuggestion> _generateFromAllClothes(
    List<Cloth> clothes,
    int maxSuggestions,
    String userId,
  ) {
    final eligible = clothes.where(_isEligibleForSuggestion).toList();
    if (!_hasMinimumOutfitCategories(eligible)) {
      return [];
    }

    final suggestions = <OutfitSuggestion>[];
    final random = Random();
    final usedIds = <String>{};

    final now = DateTime.now();
    for (int i = 0; i < maxSuggestions; i++) {
      final suggestion = _buildSuggestion(
        userId: userId,
        pool: eligible,
        index: i,
        now: now,
        random: random,
        purpose: 'fallback_suggestion',
        excludeIds: usedIds,
      );
      if (suggestion != null) {
        suggestions.add(suggestion);
        usedIds.addAll(suggestion.clothIds);
      }
    }

    return suggestions;
  }

  /// Save a suggestion to local storage
  static Future<void> saveSuggestion(String userId, OutfitSuggestion suggestion) async {
    try {
      final suggestions = await getSuggestions(userId);
      suggestions.insert(0, suggestion); // Add to beginning

      // Keep only last N suggestions
      if (suggestions.length > _maxStoredSuggestions) {
        suggestions.removeRange(_maxStoredSuggestions, suggestions.length);
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(suggestions.map((s) => s.toJson()).toList());
      await prefs.setString('$_suggestionsKey$userId', jsonString);

      if (kDebugMode) {
        debugPrint('✅ Saved suggestion: ${suggestion.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to save suggestion: $e');
      }
    }
  }

  /// Get all stored suggestions for a user (most recent first)
  static Future<List<OutfitSuggestion>> getSuggestions(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('$_suggestionsKey$userId');

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> suggestionsJson = jsonDecode(jsonString);
      return suggestionsJson
          .map((json) => OutfitSuggestion.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to load suggestions: $e');
      }
      return [];
    }
  }

  /// Get last N suggestions (default 3)
  static Future<List<OutfitSuggestion>> getLastSuggestions(String userId, {int count = 3}) async {
    final all = await getSuggestions(userId);
    return all.take(count).toList();
  }

  /// Clear all suggestions for a user
  static Future<void> clearSuggestions(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_suggestionsKey$userId');
      
      if (kDebugMode) {
        debugPrint('✅ Cleared all suggestions for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to clear suggestions: $e');
      }
    }
  }
}

