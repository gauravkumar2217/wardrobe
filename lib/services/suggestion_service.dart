import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/suggestion.dart';
import '../models/cloth.dart';
import '../models/wardrobe.dart';
import 'cloth_service.dart';
import 'notification_service.dart';

class SuggestionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get Firestore path for suggestions
  static String _suggestionsPath(String userId) {
    return 'users/$userId/suggestions';
  }

  /// Generate a suggestion for a wardrobe
  /// Algorithm: Filter by season, sort by lastWorn (oldest first), pick top N
  static Future<Suggestion> generateSuggestion(
    String userId,
    String wardrobeId,
    Wardrobe wardrobe, {
    String? occasion,
    int maxItems = 3,
  }) async {
    try {
      // Get all clothes for the wardrobe
      final clothes = await ClothService.getClothes(userId, wardrobeId);

      if (clothes.isEmpty) {
        throw Exception('No clothes available in this wardrobe');
      }

      // Filter clothes by season (match wardrobe season or "All-season")
      List<Cloth> filteredClothes = clothes.where((cloth) {
        return cloth.season == wardrobe.season || 
               cloth.season == 'All-season' ||
               wardrobe.season == 'All-season';
      }).toList();

      // Filter by occasion if specified
      if (occasion != null && occasion.isNotEmpty) {
        filteredClothes = filteredClothes.where((cloth) {
          return cloth.occasion == occasion || cloth.occasion == 'Other';
        }).toList();
      }

      if (filteredClothes.isEmpty) {
        // Fallback: use all clothes if no season match
        filteredClothes = clothes;
      }

      // Sort by lastWorn (null/oldest first) to avoid repetition
      filteredClothes.sort((a, b) {
        if (a.lastWorn == null && b.lastWorn == null) {
          return a.createdAt.compareTo(b.createdAt); // Newer first if both never worn
        }
        if (a.lastWorn == null) return -1; // Never worn comes first
        if (b.lastWorn == null) return 1;
        return a.lastWorn!.compareTo(b.lastWorn!); // Oldest first
      });

      // Pick top N items
      final suggestedClothIds = filteredClothes
          .take(maxItems)
          .map((cloth) => cloth.id)
          .toList();

      if (suggestedClothIds.isEmpty) {
        throw Exception('No suitable clothes found for suggestion');
      }

      // Generate reason
      String reason = 'Based on ${wardrobe.season} season';
      if (occasion != null && occasion.isNotEmpty) {
        reason += ' and $occasion occasion';
      }
      if (filteredClothes.isNotEmpty && filteredClothes.first.lastWorn == null) {
        reason += ' - includes unworn items';
      } else if (filteredClothes.isNotEmpty) {
        final daysSince = DateTime.now()
            .difference(filteredClothes.first.lastWorn!)
            .inDays;
        reason += ' - not worn in $daysSince days';
      }

      // Create suggestion
      final dateString = Suggestion.getTodayDateString();
      final suggestion = Suggestion(
        id: dateString,
        wardrobeId: wardrobeId,
        clothIds: suggestedClothIds,
        reason: reason,
        createdAt: DateTime.now(),
        viewed: false,
      );

      // Save to Firestore
      await _firestore
          .collection(_suggestionsPath(userId))
          .doc(dateString)
          .set(suggestion.toJson());

      // Schedule notification for tomorrow if not already scheduled
      // Don't fail suggestion generation if notification scheduling fails
      try {
        await NotificationService.scheduleDailySuggestionNotification();
      } catch (notificationError) {
        // Log but don't throw - notification is optional
        if (kDebugMode) {
          debugPrint('Failed to schedule notification: $notificationError');
        }
      }

      return suggestion;
    } catch (e) {
      throw Exception('Failed to generate suggestion: $e');
    }
  }

  /// Get today's suggestion
  static Future<Suggestion?> getTodaySuggestion(String userId) async {
    try {
      final dateString = Suggestion.getTodayDateString();
      final doc = await _firestore
          .collection(_suggestionsPath(userId))
          .doc(dateString)
          .get();

      if (!doc.exists) {
        return null;
      }

      return Suggestion.fromJson(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Failed to get today\'s suggestion: $e');
    }
  }

  /// Get suggestion history
  static Future<List<Suggestion>> getSuggestionHistory(
    String userId, {
    int limit = 30,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_suggestionsPath(userId))
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Suggestion.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get suggestion history: $e');
    }
  }

  /// Mark suggestion as viewed
  static Future<void> markAsViewed(String userId, String suggestionId) async {
    try {
      await _firestore
          .collection(_suggestionsPath(userId))
          .doc(suggestionId)
          .update({'viewed': true});
    } catch (e) {
      throw Exception('Failed to mark suggestion as viewed: $e');
    }
  }

  /// Stream today's suggestion for real-time updates
  static Stream<Suggestion?> watchTodaySuggestion(String userId) {
    final dateString = Suggestion.getTodayDateString();
    return _firestore
        .collection(_suggestionsPath(userId))
        .doc(dateString)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return Suggestion.fromJson(snapshot.data()!, snapshot.id);
    });
  }
}

