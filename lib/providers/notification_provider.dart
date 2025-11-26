import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';

/// Notification provider for managing notifications state
class NotificationProvider with ChangeNotifier {
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load notifications
  Future<void> loadNotifications(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notifications = await NotificationService.getNotifications(userId);
      _unreadCount = await NotificationService.getUnreadCount(userId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load notifications: ${e.toString()}';
      debugPrint('Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Watch notifications for real-time updates
  void watchNotifications(String userId) {
    NotificationService.watchNotifications(userId).listen((notifications) {
      _notifications = notifications;
      _errorMessage = null;
      notifyListeners();
    });

    NotificationService.watchUnreadCount(userId).listen((count) {
      _unreadCount = count;
      notifyListeners();
    });
  }

  /// Mark notification as read
  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    try {
      await NotificationService.markAsRead(
        userId: userId,
        notificationId: notificationId,
      );
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(read: true);
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to mark as read: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      await NotificationService.markAllAsRead(userId);
      _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to mark all as read: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Delete notification
  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) async {
    try {
      await NotificationService.deleteNotification(
        userId: userId,
        notificationId: notificationId,
      );
      final notification = _notifications.firstWhere((n) => n.id == notificationId);
      _notifications.removeWhere((n) => n.id == notificationId);
      if (!notification.read) {
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete notification: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

