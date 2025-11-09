import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wardrobe.dart';
import 'analytics_service.dart';
import 'subscription_service.dart';

class WardrobeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get Firestore path for user's wardrobes
  static String _wardrobesPath(String userId) {
    return 'users/$userId/wardrobes';
  }

  /// Get all wardrobes for a user (max 2 for free tier)
  static Future<List<Wardrobe>> getUserWardrobes(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_wardrobesPath(userId))
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return Wardrobe.fromJson(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch wardrobes: $e');
    }
  }

  /// Create a new wardrobe with transaction to enforce limit
  static Future<String> createWardrobe(
    String userId,
    String title,
    String location,
    String season,
  ) async {
    try {
      final wardrobesRef = _firestore.collection(_wardrobesPath(userId));
      
      // Check wardrobe limit based on subscription
      final currentSnapshot = await wardrobesRef.limit(3).get();
      final currentCount = currentSnapshot.docs.length;

      final canCreate = await SubscriptionService.canCreateWardrobe(userId, currentCount);
      if (!canCreate) {
        throw Exception('Wardrobe limit reached. Upgrade to Pro for unlimited wardrobes.');
      }

      // Create new wardrobe
      final now = DateTime.now();
      
      final wardrobeData = {
        'title': title,
        'location': location,
        'season': season,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'clothCount': 0,
      };

      final docRef = await wardrobesRef.add(wardrobeData);
      final wardrobeId = docRef.id;

      // Log analytics event
      await AnalyticsService.logWardrobeCreated(wardrobeId);

      return wardrobeId;
    } catch (e) {
      throw Exception('Failed to create wardrobe: $e');
    }
  }

  /// Update wardrobe
  static Future<void> updateWardrobe(
    String userId,
    String wardrobeId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
      
      await _firestore
          .collection(_wardrobesPath(userId))
          .doc(wardrobeId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update wardrobe: $e');
    }
  }

  /// Delete wardrobe
  static Future<void> deleteWardrobe(String userId, String wardrobeId) async {
    try {
      // Delete wardrobe and all its clothes
      final wardrobeRef = _firestore
          .collection(_wardrobesPath(userId))
          .doc(wardrobeId);

      final clothesSnapshot = await wardrobeRef
          .collection('clothes')
          .get();

      // Batch delete all clothes
      if (clothesSnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in clothesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // Delete wardrobe
      await wardrobeRef.delete();
    } catch (e) {
      throw Exception('Failed to delete wardrobe: $e');
    }
  }

  /// Stream wardrobes for real-time updates
  static Stream<List<Wardrobe>> watchUserWardrobes(String userId) {
    return _firestore
        .collection(_wardrobesPath(userId))
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Wardrobe.fromJson(doc.data(), doc.id))
          .toList();
    });
  }
}

