import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

/// FCM Service for managing device tokens
/// Stores tokens in users/{userId}/devices/{deviceId}
class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static String? _currentToken;
  static bool _isInitialized = false;

  /// Initialize FCM service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request notification permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        debugPrint('FCM Permission status: ${settings.authorizationStatus}');
      }

      // Get initial token
      _currentToken = await _messaging.getToken();
      if (kDebugMode && _currentToken != null) {
        debugPrint('Initial FCM Token: $_currentToken');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          debugPrint('FCM Token refreshed: $newToken');
        }
        _currentToken = newToken;
        // Update token in Firestore if user is logged in
        final userId = _getCurrentUserId();
        if (userId != null) {
          registerDeviceToken(userId);
        }
      });

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM Service initialization failed: $e');
      }
    }
  }

  /// Register device token for current user
  static Future<void> registerDeviceToken(String userId) async {
    if (_currentToken == null) {
      try {
        _currentToken = await _messaging.getToken();
      } catch (e) {
        debugPrint('Failed to get FCM token: $e');
        return;
      }
    }

    if (_currentToken == null) return;

    try {
      // Get device info
      final deviceInfo = DeviceInfoPlugin();
      String platform = 'unknown';
      String? deviceName;

      if (Platform.isAndroid) {
        platform = 'android';
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = androidInfo.model;
      } else if (Platform.isIOS) {
        platform = 'ios';
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        platform = 'web';
      }

      // Use token as device ID (unique per device)
      final deviceId = _currentToken!;

      final deviceData = {
        'fcmToken': _currentToken!,
        'platform': platform,
        'deviceName': deviceName ?? 'Unknown Device',
        'isActive': true,
        'lastActiveAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Store in user's devices subcollection (existing structure)
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(deviceId)
          .set(deviceData, SetOptions(merge: true));

      // Also store in new FCM tokens collection for easier querying
      // Structure: fcmTokens/{tokenId} -> { userId, token, platform, deviceName, isActive, lastActiveAt, createdAt }
      final fcmTokenData = {
        'userId': userId,
        'fcmToken': _currentToken!,
        'platform': platform,
        'deviceName': deviceName ?? 'Unknown Device',
        'isActive': true,
        'lastActiveAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('fcmTokens')
          .doc(deviceId)
          .set(fcmTokenData, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('FCM token registered for user: $userId');
      }
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  /// Update last active timestamp
  static Future<void> updateLastActive(String userId) async {
    if (_currentToken == null) return;

    try {
      // Use set with merge instead of update for better compatibility with sentinel values
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(_currentToken!)
          .set({
        'lastActiveAt': FieldValue.serverTimestamp(),
        'isActive': true,
      }, SetOptions(merge: true));

      // Also update in FCM tokens collection
      // Include userId in the update so the rule can verify ownership
      await _firestore
          .collection('fcmTokens')
          .doc(_currentToken!)
          .set({
        'userId': userId, // Include userId so rule can verify ownership
        'lastActiveAt': FieldValue.serverTimestamp(),
        'isActive': true,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to update last active: $e');
    }
  }

  /// Update app state (foreground/background)
  static Future<void> updateAppState(String userId, bool isInForeground) async {
    if (_currentToken == null) return;

    try {
      // Use set with merge instead of update for better compatibility with sentinel values
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(_currentToken!)
          .set({
        'isActive': isInForeground,
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update in FCM tokens collection
      // Include userId in the update so the rule can verify ownership
      await _firestore
          .collection('fcmTokens')
          .doc(_currentToken!)
          .set({
        'userId': userId, // Include userId so rule can verify ownership
        'isActive': isInForeground,
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to update app state: $e');
    }
  }

  /// Deactivate device token (on logout)
  static Future<void> deactivateDeviceToken(String userId) async {
    if (_currentToken == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(_currentToken!)
          .update({
        'isActive': false,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });

      // Also update in FCM tokens collection
      await _firestore
          .collection('fcmTokens')
          .doc(_currentToken!)
          .update({
        'isActive': false,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('FCM token deactivated for user: $userId');
      }
    } catch (e) {
      debugPrint('Failed to deactivate FCM token: $e');
    }
  }

  /// Get current FCM token
  static String? getCurrentToken() {
    return _currentToken;
  }

  /// Get current user ID (helper)
  static String? _getCurrentUserId() {
    // This should be called from context where user is authenticated
    // For now, return null - will be set by caller
    return null;
  }

  /// Get all active tokens for a user (for server-side use)
  /// Uses the new fcmTokens collection for easier querying
  static Future<List<String>> getActiveTokens(String userId) async {
    try {
      // Query the new fcmTokens collection by userId
      final snapshot = await _firestore
          .collection('fcmTokens')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['fcmToken'] as String)
          .where((token) => token.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Failed to get active tokens: $e');
      // Fallback to old method
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('devices')
            .where('isActive', isEqualTo: true)
            .get();

        return snapshot.docs
            .map((doc) => doc.data()['fcmToken'] as String)
            .where((token) => token.isNotEmpty)
            .toList();
      } catch (e2) {
        debugPrint('Failed to get active tokens (fallback): $e2');
        return [];
      }
    }
  }

  /// Get all active tokens for a user from fcmTokens collection (for Cloud Functions)
  /// This is the preferred method as it's faster and easier to query
  static Future<List<Map<String, dynamic>>> getActiveTokenDetails(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('fcmTokens')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'tokenId': doc.id,
          'fcmToken': data['fcmToken'] as String,
          'platform': data['platform'] as String? ?? 'unknown',
          'deviceName': data['deviceName'] as String? ?? 'Unknown Device',
          'lastActiveAt': data['lastActiveAt'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to get active token details: $e');
      return [];
    }
  }
}
