import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/notification.dart';
import 'laravel_api_client.dart';

/// In-app notifications via Laravel API (MySQL).
class NotificationService {
  static List<AppNotification> _parseList(dynamic data) {
    Iterable<dynamic> items;
    if (data is Map<String, dynamic> && data['data'] is List) {
      items = data['data'] as List;
    } else if (data is List) {
      items = data;
    } else {
      return [];
    }
    return items
        .whereType<Map>()
        .map((e) => AppNotification.fromApiJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<AppNotification>> getNotifications(String userId) async {
    try {
      final uri = Uri.parse(ApiConfig.notifications).replace(
        queryParameters: const {'per_page': '100'},
      );
      final body = await LaravelApiClient.getJson(uri.toString());
      return _parseList(LaravelApiClient.extractData(body));
    } catch (e) {
      debugPrint('Failed to get notifications: $e');
      return [];
    }
  }

  static Future<int> getUnreadCount(String userId) async {
    try {
      final body = await LaravelApiClient.getJson(ApiConfig.notificationsUnread);
      final data = LaravelApiClient.extractData(body);
      if (data is List) return data.length;
      return _parseList(data).where((n) => !n.read).length;
    } catch (e) {
      debugPrint('Failed to get unread count: $e');
      return 0;
    }
  }

  static Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    try {
      await LaravelApiClient.putJson(
        ApiConfig.notificationRead(notificationId),
        {},
      );
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
    }
  }

  static Future<void> markAllAsRead(String userId) async {
    try {
      await LaravelApiClient.putJson(ApiConfig.notificationsReadAll, {});
    } catch (e) {
      debugPrint('Failed to mark all as read: $e');
    }
  }

  static Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) async {
    try {
      await LaravelApiClient.deleteJson(
        ApiConfig.notificationDelete(notificationId),
      );
    } catch (e) {
      debugPrint('Failed to delete notification: $e');
    }
  }

  /// Poll notifications periodically (replaces Firestore snapshots).
  static Stream<List<AppNotification>> watchNotifications(String userId) async* {
    yield await getNotifications(userId);
    while (true) {
      await Future.delayed(const Duration(seconds: 20));
      yield await getNotifications(userId);
    }
  }

  static Stream<int> watchUnreadCount(String userId) async* {
    yield await getUnreadCount(userId);
    while (true) {
      await Future.delayed(const Duration(seconds: 20));
      yield await getUnreadCount(userId);
    }
  }
}
