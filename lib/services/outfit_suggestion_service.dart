import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../models/cloth.dart';
import '../models/outfit_suggestion.dart';

/// Service for generating outfit suggestions based on unworn clothes
class OutfitSuggestionService {
  static const String _suggestionsKey = 'outfit_suggestions';
  static const String _dailySuggestionKey = 'daily_outfit_suggestion';
  static const int _maxStoredSuggestions = 10; // Keep last 10 suggestions
  static const int _daysNotWornThreshold = 7; // Consider "not worn recently" if not worn in 7+ days

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
  }) {
    final excluded = excludeIds ?? const <String>{};
    final candidates = pool.where((c) {
      if (excluded.contains(c.id)) return false;
      if (itemKind != null && c.itemKind != itemKind) return false;
      return true;
    }).toList();

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
  }) {
    if (pool.length < 2) return null;

    final eligible = pool.where(_isEligibleForSuggestion).toList();
    if (eligible.length < 2) return null;

    // Prefer anchoring suggestions on real clothing items when possible.
    final eligibleCloth = eligible.where((c) => c.itemKind == 'cloth').toList();
    final anchorPool = eligibleCloth.isNotEmpty ? eligibleCloth : eligible;
    anchorPool.sort(
        (a, b) => _daysSinceWorn(b, now).compareTo(_daysSinceWorn(a, now)));
    final anchor = anchorPool.first;
    final wantedTags = _tagsFor(anchor);

    final selected = <Cloth>[anchor];
    final selectedIds = <String>{anchor.id};

    // Pick 1-2 more "cloth" items matching the anchor's tags.
    for (var i = 0; i < 2; i++) {
      final next = _pickBest(
        pool: eligible,
        wantedTags: wantedTags,
        now: now,
        random: random,
        excludeIds: selectedIds,
        itemKind: 'cloth',
      );
      if (next == null) break;
      selected.add(next);
      selectedIds.add(next.id);
    }

    // Add footwear if available.
    final footwear = _pickBest(
      pool: eligible,
      wantedTags: wantedTags,
      now: now,
      random: random,
      excludeIds: selectedIds,
      itemKind: 'footwear',
    );
    if (footwear != null) {
      selected.add(footwear);
      selectedIds.add(footwear.id);
    }

    // Add up to 2 accessories (optional).
    for (var i = 0; i < 2; i++) {
      final acc = _pickBest(
        pool: eligible,
        wantedTags: wantedTags,
        now: now,
        random: random,
        excludeIds: selectedIds,
        itemKind: 'accessories',
      );
      if (acc == null) break;
      selected.add(acc);
      selectedIds.add(acc.id);
    }

    if (selected.length < 2) return null;

    final createdAt = now;
    final suggestionId = dayKey != null
        ? '${_dailySuggestionKey}_${userId}_$dayKey'
        : '${DateTime.now().millisecondsSinceEpoch}_$index';

    final anchorDays = _daysSinceWorn(anchor, now);
    final titleParts = <String>[];
    if (anchor.category.isNotEmpty) titleParts.add(anchor.category);
    if (anchor.season.isNotEmpty) titleParts.add(anchor.season);
    final title = titleParts.isEmpty ? 'Daily Suggestion' : '${titleParts.join(' • ')} look';

    final description = anchor.wornAt == null
        ? 'Based on items you haven’t worn yet, plus matching tags (season/occasion/colors).'
        : 'Based on items you haven’t worn in $anchorDays days, plus matching tags (season/occasion/colors).';

    return OutfitSuggestion(
      id: suggestionId,
      userId: userId,
      createdAt: createdAt,
      clothIds: selected.map((c) => c.id).toList(),
      title: title,
      description: description,
      metadata: {
        if (purpose != null) 'purpose': purpose,
        if (dayKey != null) 'dayKey': dayKey,
        'anchorId': anchor.id,
        'anchorDaysSinceWorn': anchorDays,
        'anchorCategory': anchor.category,
        'anchorSeason': anchor.season,
        'anchorOccasions': anchor.occasions,
        'anchorColors': anchor.colorTags.colors,
        'includedKinds': selected.map((c) => c.itemKind).toSet().toList(),
      },
    );
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

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!forceNew) {
        final cached = prefs.getString(prefsKey);
        if (cached != null && cached.isNotEmpty) {
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
        );
        if (suggestion != null) {
          suggestions.add(suggestion);
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
    if (eligible.length < 2) {
      return [];
    }

    final suggestions = <OutfitSuggestion>[];
    final random = Random();

    final now = DateTime.now();
    for (int i = 0; i < maxSuggestions; i++) {
      final suggestion = _buildSuggestion(
        userId: userId,
        pool: eligible,
        index: i,
        now: now,
        random: random,
        purpose: 'fallback_suggestion',
      );
      if (suggestion != null) {
        suggestions.add(suggestion);
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

