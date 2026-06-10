import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import '../config/api_config.dart';
import 'laravel_api_client.dart';

/// FCM Service — registers tokens via Laravel API (MySQL).
class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _currentToken;
  static String? _registeredDeviceId;
  static String? _registeredFcmRecordId;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        debugPrint('FCM Permission status: ${settings.authorizationStatus}');
      }

      if (Platform.isIOS) {
        try {
          await _messaging.getAPNSToken();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('APNS token check (may be normal in simulator): $e');
          }
        }
      }

      _currentToken = await _messaging.getToken();
      if (kDebugMode && _currentToken != null) {
        debugPrint('Initial FCM Token obtained');
      }

      _messaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) debugPrint('FCM Token refreshed');
        _currentToken = newToken;
        _registeredDeviceId = null;
        _registeredFcmRecordId = null;
      });

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('FCM Service initialization failed: $e');
    }
  }

  static Future<void> registerDeviceToken(String userId) async {
    if (_currentToken == null) {
      try {
        if (Platform.isIOS) {
          try {
            await _messaging.getAPNSToken();
          } catch (_) {}
        }
        _currentToken = await _messaging.getToken();
      } catch (e) {
        debugPrint('Failed to get FCM token: $e');
        if (Platform.isIOS && e.toString().contains('apns-token-not-set')) {
          try {
            await _messaging.getAPNSToken();
            await Future.delayed(const Duration(milliseconds: 500));
            _currentToken = await _messaging.getToken();
          } catch (retryError) {
            debugPrint('Failed to get FCM token after retry: $retryError');
            return;
          }
        } else {
          return;
        }
      }
    }

    if (_currentToken == null) return;

    try {
      final deviceInfo = DeviceInfoPlugin();
      String platform = 'web';
      String? deviceName;

      if (Platform.isAndroid) {
        platform = 'android';
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = androidInfo.model;
      } else if (Platform.isIOS) {
        platform = 'ios';
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
      }

      final deviceBody = await LaravelApiClient.postJson(
        ApiConfig.devices,
        {
          'fcm_token': _currentToken!,
          'platform': platform,
          'device_name': deviceName ?? 'Unknown Device',
        },
      );
      final deviceData = LaravelApiClient.extractData(deviceBody);
      if (deviceData is Map<String, dynamic>) {
        _registeredDeviceId = deviceData['id']?.toString();
      }

      final tokenBody = await LaravelApiClient.postJson(
        ApiConfig.fcmTokens,
        {'token': _currentToken!},
      );
      final tokenData = LaravelApiClient.extractData(tokenBody);
      if (tokenData is Map<String, dynamic>) {
        _registeredFcmRecordId = tokenData['id']?.toString();
      }

      if (kDebugMode) {
        debugPrint('FCM token registered via Laravel for user: $userId');
      }
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  static Future<void> updateLastActive(String userId) async {
    await _setActive(userId, isActive: true);
  }

  static Future<void> updateAppState(String userId, bool isInForeground) async {
    await _setActive(userId, isActive: isInForeground);
  }

  static Future<void> _setActive(String userId, {required bool isActive}) async {
    if (_currentToken == null) return;
    try {
      if (_registeredDeviceId != null) {
        await LaravelApiClient.putJson(
          ApiConfig.deviceActive(_registeredDeviceId!),
          {'is_active': isActive},
        );
      }
      if (_registeredFcmRecordId != null) {
        await LaravelApiClient.putJson(
          ApiConfig.fcmTokenActive(_registeredFcmRecordId!),
          {'is_active': isActive},
        );
      }
    } catch (e) {
      debugPrint('Failed to update device active state: $e');
    }
  }

  static Future<void> deactivateDeviceToken(String userId) async {
    if (_currentToken == null) return;
    try {
      await _setActive(userId, isActive: false);
      if (kDebugMode) {
        debugPrint('FCM token deactivated via Laravel for user: $userId');
      }
    } catch (e) {
      debugPrint('Failed to deactivate FCM token: $e');
    }
  }

  static String? getCurrentToken() => _currentToken;

  /// Legacy helpers — push delivery is server-side via Laravel `fcm_tokens` table.
  static Future<List<String>> getActiveTokens(String userId) async => [];

  static Future<List<Map<String, dynamic>>> getActiveTokenDetails(
    String userId,
  ) async =>
      [];
}
