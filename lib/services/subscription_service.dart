import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription.dart';

class SubscriptionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user's subscription plan
  static Future<Subscription> getUserSubscription(String userId) async {
    try {
      final doc = await _firestore.doc('users/$userId').get();
      
      if (!doc.exists) {
        return Subscription.free();
      }

      final data = doc.data();
      if (data == null || data['plan'] == null) {
        return Subscription.free();
      }

      return Subscription.fromJson(data['plan'] as Map<String, dynamic>);
    } catch (e) {
      return Subscription.free();
    }
  }

  /// Update user's subscription plan
  static Future<void> updateSubscription(
    String userId,
    Subscription subscription,
  ) async {
    try {
      await _firestore.doc('users/$userId').set({
        'plan': subscription.toJson(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update subscription: $e');
    }
  }

  /// Check if user can create more wardrobes
  static Future<bool> canCreateWardrobe(String userId, int currentCount) async {
    final subscription = await getUserSubscription(userId);
    
    if (subscription.isExpired) {
      return currentCount < 2; // Fallback to free plan
    }

    if (subscription.maxWardrobes == -1) {
      return true; // Unlimited
    }

    return currentCount < subscription.maxWardrobes;
  }
}

