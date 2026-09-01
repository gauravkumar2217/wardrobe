import 'package:flutter/foundation.dart';

import 'fcm_service.dart';
import 'laravel_auth_service.dart';

/// Legacy alias — all token persistence goes through Laravel API.
class FCMTokenService {
  static Future<void> initialize() => FCMService.initialize();

  static Future<void> saveTokenForCurrentUser() async {
    final userId = await LaravelAuthService.getCurrentUserId();
    if (userId == null) {
      if (kDebugMode) {
        debugPrint('Cannot save FCM token: user not authenticated');
      }
      return;
    }
    await FCMService.registerDeviceToken(userId);
  }

  static Future<void> deactivateTokenForCurrentUser() async {
    final userId = await LaravelAuthService.getCurrentUserId();
    final token = FCMService.getCurrentToken();
    if (userId == null || token == null) return;
    await FCMService.deactivateDeviceToken(userId);
  }

  static Future<void> deactivateToken(String userId, String token) async {
    await FCMService.deactivateDeviceToken(userId);
  }

  static Future<void> deleteTokenForCurrentUser() async {
    await deactivateTokenForCurrentUser();
  }

  static Future<void> updateLastActive() async {
    final userId = await LaravelAuthService.getCurrentUserId();
    if (userId == null) return;
    await FCMService.updateLastActive(userId);
  }

  static String? getCurrentToken() => FCMService.getCurrentToken();
}
