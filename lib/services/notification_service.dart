import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification.dart';

/// Notification service for managing in-app notifications
class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get notifications path
  static String _notificationsPath(String userId) {
    return 'users/$userId/notifications';
  }

  /// Get notifications for a user
  static Future<List<AppNotification>> getNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_notificationsPath(userId))
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => AppNotification.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Failed to get notifications: $e');
      return [];
    }
  }

  /// Get unread notifications count
  static Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_notificationsPath(userId))
          .where('read', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Failed to get unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  static Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    try {
      await _firestore
          .collection(_notificationsPath(userId))
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_notificationsPath(userId))
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to mark all as read: $e');
    }
  }

  /// Delete notification
  static Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) async {
    try {
      await _firestore
          .collection(_notificationsPath(userId))
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('Failed to delete notification: $e');
    }
  }

  /// Stream notifications for real-time updates
  static Stream<List<AppNotification>> watchNotifications(String userId) {
    return _firestore
        .collection(_notificationsPath(userId))
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromJson(doc.data(), doc.id))
            .toList());
  }

  /// Stream unread count for real-time updates
  static Stream<int> watchUnreadCount(String userId) {
    return _firestore
        .collection(_notificationsPath(userId))
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
