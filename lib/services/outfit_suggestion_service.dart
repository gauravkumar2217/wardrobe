import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../models/cloth.dart';
import '../models/outfit_suggestion.dart';
import '../services/cloth_service.dart';

/// Service for generating outfit suggestions based on unworn clothes
class OutfitSuggestionService {
  static const String _suggestionsKey = 'outfit_suggestions';
  static const int _maxStoredSuggestions = 10; // Keep last 10 suggestions
  static const int _daysNotWornThreshold = 7; // Consider "not worn recently" if not worn in 7+ days

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

      // Filter clothes that haven't been worn recently
      final unwornClothes = availableClothes.where((cloth) {
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
        return _generateFromAllClothes(availableClothes, maxSuggestions, userId);
      }

      // Group clothes by type for better outfit combinations
      final clothesByType = <String, List<Cloth>>{};
      for (final cloth in unwornClothes) {
        clothesByType.putIfAbsent(cloth.clothType, () => []).add(cloth);
      }

      final suggestions = <OutfitSuggestion>[];
      final random = Random();

      // Generate suggestions
      for (int i = 0; i < maxSuggestions && unwornClothes.isNotEmpty; i++) {
        final outfitClothes = <Cloth>[];

        // Try to create a balanced outfit (top, bottom, outerwear, accessories)
        final typesToInclude = ['Top', 'Bottom', 'Outerwear', 'Accessories'];
        
        for (final type in typesToInclude) {
          final availableOfType = clothesByType[type] ?? [];
          if (availableOfType.isNotEmpty) {
            final selected = availableOfType[random.nextInt(availableOfType.length)];
            outfitClothes.add(selected);
            // Remove from available to avoid duplicates in same suggestion
            availableOfType.remove(selected);
            clothesByType[type] = availableOfType;
          }
        }

        // If we don't have enough clothes, add random ones
        while (outfitClothes.length < 2 && unwornClothes.isNotEmpty) {
          final randomCloth = unwornClothes[random.nextInt(unwornClothes.length)];
          if (!outfitClothes.any((c) => c.id == randomCloth.id)) {
            outfitClothes.add(randomCloth);
          } else {
            // If all clothes are already included, break
            break;
          }
        }

        if (outfitClothes.length >= 2) {
          final suggestion = OutfitSuggestion(
            id: DateTime.now().millisecondsSinceEpoch.toString() + '_$i',
            userId: userId,
            createdAt: DateTime.now(),
            clothIds: outfitClothes.map((c) => c.id).toList(),
            title: _generateSuggestionTitle(outfitClothes),
            description: _generateSuggestionDescription(outfitClothes),
            metadata: {
              'clothCount': outfitClothes.length,
              'types': outfitClothes.map((c) => c.clothType).toList(),
              'seasons': outfitClothes.map((c) => c.season).toSet().toList(),
            },
          );
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
    if (clothes.length < 2) {
      return [];
    }

    final suggestions = <OutfitSuggestion>[];
    final random = Random();

    for (int i = 0; i < maxSuggestions && i < clothes.length ~/ 2; i++) {
      final selectedClothes = <Cloth>[];
      final usedIndices = <int>{};

      // Select 2-3 random clothes
      final count = min(3, clothes.length);
      while (selectedClothes.length < count && usedIndices.length < clothes.length) {
        final index = random.nextInt(clothes.length);
        if (!usedIndices.contains(index)) {
          usedIndices.add(index);
          selectedClothes.add(clothes[index]);
        }
      }

      if (selectedClothes.length >= 2) {
        suggestions.add(OutfitSuggestion(
          id: DateTime.now().millisecondsSinceEpoch.toString() + '_$i',
          userId: userId,
          createdAt: DateTime.now(),
          clothIds: selectedClothes.map((c) => c.id).toList(),
          title: _generateSuggestionTitle(selectedClothes),
          description: _generateSuggestionDescription(selectedClothes),
          metadata: {
            'clothCount': selectedClothes.length,
            'types': selectedClothes.map((c) => c.clothType).toList(),
          },
        ));
      }
    }

    return suggestions;
  }

  /// Generate a title for the suggestion
  static String _generateSuggestionTitle(List<Cloth> clothes) {
    if (clothes.isEmpty) return 'Outfit Suggestion';
    
    final types = clothes.map((c) => c.clothType).toSet().toList();
    if (types.length == 1) {
      return '${types.first} Outfit';
    }
    return '${types.length} Piece Outfit';
  }

  /// Generate a description for the suggestion
  static String _generateSuggestionDescription(List<Cloth> clothes) {
    if (clothes.isEmpty) return 'Try this outfit today!';
    
    final unwornCount = clothes.where((c) => c.wornAt == null).length;
    if (unwornCount > 0) {
      return 'You haven\'t worn ${unwornCount} of these items recently. Perfect time to try them!';
    }
    
    final daysSinceWorn = clothes
        .where((c) => c.wornAt != null)
        .map((c) => DateTime.now().difference(c.wornAt!).inDays)
        .fold<int>(0, (sum, days) => sum + days) ~/ clothes.length;
    
    return 'Haven\'t worn these in about $daysSinceWorn days. Give them another chance!';
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

