import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing onboarding completion status
class OnboardingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if user has completed onboarding
  static Future<bool> hasCompletedOnboarding(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final data = userDoc.data();
      if (data == null) return false;

      // Check settings.onboardingCompleted
      if (data['settings'] != null) {
        final settings = data['settings'] as Map<String, dynamic>;
        return settings['onboardingCompleted'] as bool? ?? false;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
      return false;
    }
  }

  /// Mark onboarding as completed
  static Future<void> completeOnboarding(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      
      // Get current settings or create new
      final userDoc = await userRef.get();
      Map<String, dynamic> settings = {};
      
      if (userDoc.exists && userDoc.data()?['settings'] != null) {
        settings = Map<String, dynamic>.from(userDoc.data()!['settings'] as Map);
      }

      // Update onboarding status
      settings['onboardingCompleted'] = true;

      // Update user document
      await userRef.set({
        'settings': settings,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      rethrow;
    }
  }

  /// Mark onboarding as skipped
  static Future<void> skipOnboarding(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      
      // Get current settings or create new
      final userDoc = await userRef.get();
      Map<String, dynamic> settings = {};
      
      if (userDoc.exists && userDoc.data()?['settings'] != null) {
        settings = Map<String, dynamic>.from(userDoc.data()!['settings'] as Map);
      }

      // Mark as skipped (also means completed, but user skipped)
      settings['onboardingCompleted'] = true;
      settings['onboardingSkipped'] = true;

      // Update user document
      await userRef.set({
        'settings': settings,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error skipping onboarding: $e');
      rethrow;
    }
  }
}

