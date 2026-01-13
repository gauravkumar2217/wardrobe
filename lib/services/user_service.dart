import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../models/eula_acceptance.dart';

/// User service for managing user profiles
class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user profile
  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      debugPrint('🔍 UserService: Fetching profile for userId: $userId');
      final doc = await _firestore.collection('users').doc(userId).get();

      debugPrint('   Document exists: ${doc.exists}');
      
      if (!doc.exists || doc.data() == null) {
        debugPrint('❌ UserService: Profile not found or data is null for $userId');
        return null;
      }

      final data = doc.data()!;
      debugPrint('   Profile data keys: ${data.keys.toList()}');
      debugPrint('   displayName: ${data['displayName']}');
      debugPrint('   photoUrl: ${data['photoUrl']}');
      debugPrint('   username: ${data['username']}');
      
      final profile = UserProfile.fromJson(data);
      debugPrint('✅ UserService: Successfully loaded profile for $userId');
      debugPrint('   Profile displayName: ${profile.displayName}');
      debugPrint('   Profile photoUrl: ${profile.photoUrl}');
      
      return profile;
    } catch (e, stackTrace) {
      debugPrint('❌ UserService: Failed to fetch user profile for $userId: $e');
      debugPrint('   Error type: ${e.runtimeType}');
      debugPrint('   StackTrace: $stackTrace');
      return null;
    }
  }

  /// Create or update user profile
  static Future<void> createOrUpdateProfile({
    required String userId,
    required UserProfile profile,
  }) async {
    try {
      final profileData = profile.toJson();
      profileData['updatedAt'] = FieldValue.serverTimestamp();
      
      if (!profileData.containsKey('createdAt')) {
        profileData['createdAt'] = FieldValue.serverTimestamp();
      }

      debugPrint('Saving profile for user $userId with data: $profileData');
      debugPrint('Username in profile: ${profileData['username']}');

      await _firestore
          .collection('users')
          .doc(userId)
          .set(profileData, SetOptions(merge: true));

      debugPrint('Profile saved successfully for user $userId');
      
      // Verify the save by reading it back
      final savedDoc = await _firestore.collection('users').doc(userId).get();
      if (savedDoc.exists) {
        final savedData = savedDoc.data();
        debugPrint('Verified saved profile - username: ${savedData?['username']}');
      }
    } catch (e) {
      debugPrint('Failed to create/update user profile: $e');
      rethrow;
    }
  }

  /// Update user profile (partial update)
  static Future<void> updateProfile({
    required String userId,
    Map<String, dynamic>? updates,
    UserProfile? profile,
  }) async {
    try {
      if (profile != null) {
        final profileData = profile.toJson();
        profileData['updatedAt'] = FieldValue.serverTimestamp();
        await _firestore
            .collection('users')
            .doc(userId)
            .update(profileData);
      } else if (updates != null) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        await _firestore
            .collection('users')
            .doc(userId)
            .update(updates);
      }
    } catch (e) {
      debugPrint('Failed to update user profile: $e');
      rethrow;
    }
  }

  /// Update notification settings
  static Future<void> updateNotificationSettings({
    required String userId,
    required NotificationSettings settings,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'settings.notifications': settings.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to update notification settings: $e');
      rethrow;
    }
  }

  /// Update privacy settings
  static Future<void> updatePrivacySettings({
    required String userId,
    required PrivacySettings privacy,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'settings.privacy': privacy.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to update privacy settings: $e');
      rethrow;
    }
  }

  /// Search users by name, username, email, or phone
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      // Note: Firestore doesn't support full-text search natively
      // This is a basic implementation - consider using Algolia or similar for production
      final usersRef = _firestore.collection('users');
      final normalizedQuery = query.trim().toLowerCase();
      
      if (normalizedQuery.isEmpty) {
        return [];
      }

      final results = <Map<String, dynamic>>[];
      final seenUserIds = <String>{};

      // Helper function to add result if not already seen
      void addResult(doc) {
        if (!seenUserIds.contains(doc.id)) {
          final data = doc.data();
          results.add({
            'userId': doc.id,
            'displayName': data['displayName'] as String?,
            'username': data['username'] as String?,
            'photoUrl': data['photoUrl'] as String?,
            'email': data['email'] as String?,
            'phone': data['phone'] as String? ?? data['phoneNumber'] as String?,
          });
          seenUserIds.add(doc.id);
        }
      }

      // Search by displayName (prefix match)
      try {
        final nameQuery = await usersRef
            .where('displayName', isGreaterThanOrEqualTo: query)
            .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(20)
            .get();
        
        for (var doc in nameQuery.docs) {
          addResult(doc);
        }
      } catch (e) {
        debugPrint('Error searching by displayName: $e');
      }

      // Search by username (exact match or prefix match)
      try {
        // Try exact match first
        final usernameExactQuery = await usersRef
            .where('username', isEqualTo: normalizedQuery)
            .limit(5)
            .get();
        
        for (var doc in usernameExactQuery.docs) {
          addResult(doc);
        }

        // Try prefix match for username
        final usernamePrefixQuery = await usersRef
            .where('username', isGreaterThanOrEqualTo: normalizedQuery)
            .where('username', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
            .limit(15)
            .get();
        
        for (var doc in usernamePrefixQuery.docs) {
          addResult(doc);
        }
      } catch (e) {
        debugPrint('Error searching by username: $e');
        // If index error, try without prefix match
        try {
          final usernameExactQuery = await usersRef
              .where('username', isEqualTo: normalizedQuery)
              .limit(20)
              .get();
          
          for (var doc in usernameExactQuery.docs) {
            addResult(doc);
          }
        } catch (e2) {
          debugPrint('Error searching by username (exact only): $e2');
        }
      }

      // Search by email (exact match or prefix match)
      try {
        final emailQuery = await usersRef
            .where('email', isGreaterThanOrEqualTo: query.toLowerCase())
            .where('email', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
            .limit(20)
            .get();
        
        for (var doc in emailQuery.docs) {
          addResult(doc);
        }
      } catch (e) {
        debugPrint('Error searching by email: $e');
        // Try exact match only
        try {
          final emailExactQuery = await usersRef
              .where('email', isEqualTo: query.toLowerCase())
              .limit(20)
              .get();
          
          for (var doc in emailExactQuery.docs) {
            addResult(doc);
          }
        } catch (e2) {
          debugPrint('Error searching by email (exact only): $e2');
        }
      }

      // Search by phone (exact match)
      try {
        // Try both 'phone' and 'phoneNumber' fields
        final phoneQuery = await usersRef
            .where('phone', isEqualTo: query)
            .limit(20)
            .get();
        
        for (var doc in phoneQuery.docs) {
          addResult(doc);
        }
      } catch (e) {
        debugPrint('Error searching by phone: $e');
      }

      try {
        final phoneNumberQuery = await usersRef
            .where('phoneNumber', isEqualTo: query)
            .limit(20)
            .get();
        
        for (var doc in phoneNumberQuery.docs) {
          addResult(doc);
        }
      } catch (e) {
        debugPrint('Error searching by phoneNumber: $e');
      }

      // Limit total results to 20
      return results.take(20).toList();
    } catch (e) {
      debugPrint('Failed to search users: $e');
      return [];
    }
  }

  /// Get user by ID (public info only)
  static Future<Map<String, dynamic>?> getUserPublicInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (!doc.exists) return null;

      final data = doc.data()!;
      return {
        'userId': doc.id,
        'displayName': data['displayName'] as String?,
        'photoUrl': data['photoUrl'] as String?,
      };
    } catch (e) {
      debugPrint('Failed to get user public info: $e');
      return null;
    }
  }

  /// Delete user account
  static Future<void> deleteAccount(String userId) async {
    try {
      // Note: This should be handled by Cloud Function for complete cleanup
      // This only deletes the user profile document
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      debugPrint('Failed to delete account: $e');
      rethrow;
    }
  }

  /// Stream user profile for real-time updates
  static Stream<UserProfile?> watchUserProfile(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return UserProfile.fromJson(snapshot.data()!);
    });
  }

  /// Check if username is available (unique)
  static Future<bool> isUsernameAvailable(String username) async {
    try {
      final normalizedUsername = username.toLowerCase().trim();
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: normalizedUsername)
          .limit(1)
          .get();
      
      return query.docs.isEmpty;
    } catch (e) {
      debugPrint('Failed to check username availability: $e');
      return false;
    }
  }

  /// Get user email by username (for login)
  static Future<String?> getEmailByUsername(String username) async {
    try {
      final normalizedUsername = username.toLowerCase().trim();
      
      if (normalizedUsername.isEmpty) {
        debugPrint('Username is empty');
        return null;
      }
      
      debugPrint('Looking up username: $normalizedUsername');
      
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: normalizedUsername)
          .limit(1)
          .get();
      
      debugPrint('Query returned ${query.docs.length} documents');
      
      if (query.docs.isEmpty) {
        debugPrint('No user found with username: $normalizedUsername');
        // Try to find any users with username field for debugging
        final allUsers = await _firestore
            .collection('users')
            .limit(5)
            .get();
        debugPrint('Sample users in database: ${allUsers.docs.map((doc) => doc.data()['username']).toList()}');
        return null;
      }
      
      final data = query.docs.first.data();
      final email = data['email'] as String?;
      debugPrint('Found email for username $normalizedUsername: $email');
      return email;
    } catch (e) {
      debugPrint('Failed to get email by username: $e');
      // Check if it's an index error
      if (e.toString().contains('index') || e.toString().contains('Index')) {
        debugPrint('ERROR: Firestore index required for username queries. Please create an index on users collection for username field.');
      }
      return null;
    }
  }

  /// Record EULA acceptance
  static Future<void> recordEulaAcceptance({
    required String userId,
    required String version,
    String? ipAddress,
  }) async {
    try {
      final acceptanceId = _firestore.collection('eulaAcceptances').doc().id;
      final acceptance = EulaAcceptance(
        id: acceptanceId,
        userId: userId,
        version: version,
        acceptedAt: DateTime.now(),
        ipAddress: ipAddress,
      );

      // Store in user's subcollection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('eulaAcceptances')
          .doc(acceptanceId)
          .set(acceptance.toJson());

      // Also store in top-level collection for easy querying
      await _firestore
          .collection('eulaAcceptances')
          .doc(acceptanceId)
          .set(acceptance.toJson());
    } catch (e) {
      debugPrint('Failed to record EULA acceptance: $e');
      rethrow;
    }
  }

  /// Check if user has accepted EULA
  static Future<bool> hasAcceptedEula(String userId) async {
    try {
      final query = await _firestore
          .collection('users')
          .doc(userId)
          .collection('eulaAcceptances')
          .orderBy('acceptedAt', descending: true)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Failed to check EULA acceptance: $e');
      return false;
    }
  }

  /// Get latest EULA acceptance
  static Future<EulaAcceptance?> getLatestEulaAcceptance(String userId) async {
    try {
      final query = await _firestore
          .collection('users')
          .doc(userId)
          .collection('eulaAcceptances')
          .orderBy('acceptedAt', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final doc = query.docs.first;
      return EulaAcceptance.fromJson(doc.data(), doc.id);
    } catch (e) {
      debugPrint('Failed to get latest EULA acceptance: $e');
      return null;
    }
  }

  /// Get current EULA version
  static String getCurrentEulaVersion() {
    // Update this when Terms & Conditions change
    return '1.0';
  }
}
