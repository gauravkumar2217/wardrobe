import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user profile document path
  static String _userProfilePath(String userId) {
    return 'users/$userId';
  }

  /// Get user profile
  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.doc(_userProfilePath(userId)).get();
      
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      final data = doc.data()!;
      // Check if profile data exists (not just wardrobes subcollection)
      if (data.containsKey('name') || data.containsKey('gender') || data.containsKey('birthday')) {
        return UserProfile.fromJson(data);
      }
      
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user profile: $e');
    }
  }

  /// Update user profile
  static Future<void> updateUserProfile(
    String userId,
    UserProfile profile,
  ) async {
    try {
      final profileData = profile.toJson();
      
      // Use merge to preserve existing data like wardrobes subcollection
      await _firestore
          .doc(_userProfilePath(userId))
          .set(profileData, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Check if user profile is complete
  static Future<bool> isProfileComplete(String userId) async {
    try {
      final profile = await getUserProfile(userId);
      return profile?.isComplete ?? false;
    } catch (e) {
      return false;
    }
  }
}




