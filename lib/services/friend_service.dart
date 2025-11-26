import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/friend_request.dart';

/// Friend service for managing friend relationships
class FriendService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send friend request
  static Future<String> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
  }) async {
    try {
      // Validate: can't send request to self
      if (fromUserId == toUserId) {
        throw Exception('Cannot send friend request to yourself');
      }

      // Check if request already exists
      final existingRequest = await _firestore
          .collection('friendRequests')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('Friend request already sent');
      }

      // Check if already friends
      final isFriend = await checkFriendship(fromUserId, toUserId);
      if (isFriend) {
        throw Exception('Already friends');
      }

      // Create friend request
      final now = DateTime.now();
      final requestData = {
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'status': 'pending',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final docRef = await _firestore
          .collection('friendRequests')
          .add(requestData);

      return docRef.id;
    } catch (e) {
      debugPrint('Failed to send friend request: $e');
      rethrow;
    }
  }

  /// Accept friend request
  static Future<void> acceptFriendRequest(String requestId) async {
    try {
      final requestDoc =
          await _firestore.collection('friendRequests').doc(requestId).get();

      if (!requestDoc.exists) {
        throw Exception('Friend request not found');
      }

      final request = FriendRequest.fromJson(requestDoc.data()!, requestId);

      if (request.status != 'pending') {
        throw Exception('Friend request is not pending');
      }

      // Update request status
      await _firestore.collection('friendRequests').doc(requestId).update({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create friend documents in both users' friends subcollections
      // Note: This should be done by Cloud Function, but we'll do it here too
      final now = DateTime.now();
      final batch = _firestore.batch();

      // Add to fromUserId's friends
      batch.set(
        _firestore
            .collection('users')
            .doc(request.fromUserId)
            .collection('friends')
            .doc(request.toUserId),
        {
          'friendId': request.toUserId,
          'createdAt': Timestamp.fromDate(now),
        },
      );

      // Add to toUserId's friends
      batch.set(
        _firestore
            .collection('users')
            .doc(request.toUserId)
            .collection('friends')
            .doc(request.fromUserId),
        {
          'friendId': request.fromUserId,
          'createdAt': Timestamp.fromDate(now),
        },
      );

      await batch.commit();
    } catch (e) {
      debugPrint('Failed to accept friend request: $e');
      rethrow;
    }
  }

  /// Reject friend request
  static Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friendRequests').doc(requestId).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to reject friend request: $e');
      rethrow;
    }
  }

  /// Cancel friend request
  static Future<void> cancelFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friendRequests').doc(requestId).update({
        'status': 'canceled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to cancel friend request: $e');
      rethrow;
    }
  }

  /// Get friend requests for a user
  static Future<List<FriendRequest>> getFriendRequests({
    required String userId,
    required String type, // 'incoming' or 'outgoing'
  }) async {
    try {
      Query query;
      
      if (type == 'incoming') {
        query = _firestore
            .collection('friendRequests')
            .where('toUserId', isEqualTo: userId)
            .where('status', isEqualTo: 'pending');
      } else {
        query = _firestore
            .collection('friendRequests')
            .where('fromUserId', isEqualTo: userId)
            .where('status', isEqualTo: 'pending');
      }

      final snapshot = await query.orderBy('createdAt', descending: true).get();

      return snapshot.docs
          .map((doc) => FriendRequest.fromJson(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      debugPrint('Failed to get friend requests: $e');
      return [];
    }
  }

  /// Get friends list
  static Future<List<String>> getFriends(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('Failed to get friends list: $e');
      return [];
    }
  }

  /// Check if two users are friends
  static Future<bool> checkFriendship(String userId1, String userId2) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId1)
          .collection('friends')
          .doc(userId2)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('Failed to check friendship: $e');
      return false;
    }
  }

  /// Remove friend
  static Future<void> removeFriend({
    required String userId,
    required String friendId,
  }) async {
    try {
      // Remove from both users' friends lists
      final batch = _firestore.batch();

      batch.delete(
        _firestore
            .collection('users')
            .doc(userId)
            .collection('friends')
            .doc(friendId),
      );

      batch.delete(
        _firestore
            .collection('users')
            .doc(friendId)
            .collection('friends')
            .doc(userId),
      );

      await batch.commit();
    } catch (e) {
      debugPrint('Failed to remove friend: $e');
      rethrow;
    }
  }

  /// Stream friends list for real-time updates
  static Stream<List<String>> watchFriends(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  /// Stream friend requests for real-time updates
  static Stream<List<FriendRequest>> watchFriendRequests({
    required String userId,
    required String type,
  }) {
    Query query;
    
    if (type == 'incoming') {
      query = _firestore
          .collection('friendRequests')
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending');
    } else {
      query = _firestore
          .collection('friendRequests')
          .where('fromUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending');
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendRequest.fromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }
}

