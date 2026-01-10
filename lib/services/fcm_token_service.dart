import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// Service to manage FCM tokens for push notifications
/// Handles token storage, updates, and cleanup for active users only
class FCMTokenService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static String? _currentToken;
  static bool _isInitialized = false;

  /// Initialize FCM token service
  /// Should be called once when app starts
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request notification permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        debugPrint('FCM Permission status: ${settings.authorizationStatus}');
      }

      // On iOS, get APNS token first before getting FCM token
      if (Platform.isIOS) {
        try {
          final apnsToken = await _messaging.getAPNSToken();
          if (kDebugMode) {
            if (apnsToken != null) {
              debugPrint('APNS Token obtained: $apnsToken');
            } else {
              debugPrint('APNS Token is null (may be normal in simulator)');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Failed to get APNS token (may be normal in simulator): $e');
          }
          // Continue anyway - APNS token may not be available in simulator
        }
      }

      // Get initial token
      _currentToken = await _messaging.getToken();
      if (kDebugMode) {
        debugPrint('Initial FCM Token: $_currentToken');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          debugPrint('FCM Token refreshed: $newToken');
        }
        _currentToken = newToken;
        _saveTokenToFirestore(newToken);
      });

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM Token Service initialization failed: $e');
      }
    }
  }

  /// Save FCM token to Firestore for the current user
  /// Only saves if user is authenticated
  static Future<void> saveTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        debugPrint('Cannot save FCM token: User not authenticated');
      }
      return;
    }

    if (_currentToken == null) {
      // Try to get token if not already available
      try {
        // On iOS, ensure APNS token is available first
        if (Platform.isIOS) {
          try {
            final apnsToken = await _messaging.getAPNSToken();
            if (kDebugMode && apnsToken != null) {
              debugPrint('APNS Token obtained before FCM token: $apnsToken');
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('APNS token check failed (may be normal): $e');
            }
            // Continue anyway - will retry if needed
          }
        }
        
        _currentToken = await _messaging.getToken();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to get FCM token: $e');
        }
        
        // On iOS, if APNS token error, try to get APNS token first and retry
        if (Platform.isIOS && e.toString().contains('apns-token-not-set')) {
          try {
            if (kDebugMode) {
              debugPrint('Retrying after getting APNS token...');
            }
            await _messaging.getAPNSToken();
            // Wait a moment for APNS token to be set
            await Future.delayed(const Duration(milliseconds: 500));
            _currentToken = await _messaging.getToken();
            if (kDebugMode && _currentToken != null) {
              debugPrint('FCM Token obtained after APNS token: $_currentToken');
            }
          } catch (retryError) {
            if (kDebugMode) {
              debugPrint('Failed to get FCM token after retry: $retryError');
            }
            return;
          }
        } else {
          return;
        }
      }
    }

    if (_currentToken != null) {
      await _saveTokenToFirestore(_currentToken!);
    }
  }

  /// Save token to Firestore
  static Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        debugPrint('Cannot save FCM token: User not authenticated');
      }
      return;
    }

    try {
      final tokenData = {
        'token': token,
        'userId': user.uid,
        'isActive': true,
        'lastActive': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Use token as document ID to ensure uniqueness per device
      // Store in users/{userId}/fcmTokens/{token}
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(token)
          .set(tokenData, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('FCM token saved to Firestore for user: ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to save FCM token to Firestore: $e');
      }
    }
  }

  /// Mark FCM token as inactive (for logout)
  /// This ensures push notifications won't be sent to logged out users
  static Future<void> deactivateTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentToken == null) {
      if (kDebugMode) {
        debugPrint('Cannot deactivate FCM token: User not authenticated or token not available');
      }
      return;
    }

    // Use the overloaded method with explicit user ID and token
    await deactivateToken(user.uid, _currentToken!);
  }

  /// Mark FCM token as inactive by user ID and token (for logout after sign out)
  /// This allows deactivating tokens even after the user has been signed out
  static Future<void> deactivateToken(String userId, String token) async {
    if (userId.isEmpty || token.isEmpty) {
      if (kDebugMode) {
        debugPrint('Cannot deactivate FCM token: Invalid userId or token');
      }
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('fcmTokens')
          .doc(token)
          .update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'deactivatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('FCM token deactivated for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to deactivate FCM token: $e');
      }
      // Don't throw - this is not critical for logout
    }
  }

  /// Delete FCM token from Firestore (for app uninstall scenario)
  /// Note: This is called when we detect app termination, but actual uninstall
  /// detection is not possible. Server-side cleanup is recommended.
  static Future<void> deleteTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentToken == null) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(_currentToken!)
          .delete();

      if (kDebugMode) {
        debugPrint('FCM token deleted for user: ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to delete FCM token: $e');
      }
    }
  }

  /// Update last active timestamp for the current token
  /// Call this periodically to track active users
  static Future<void> updateLastActive() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentToken == null) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(_currentToken!)
          .update({
        'lastActive': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to update last active: $e');
      }
    }
  }

  /// Get current FCM token
  static String? getCurrentToken() {
    return _currentToken;
  }

  /// Get all active tokens for a user (for server-side use)
  /// Returns a stream of active tokens
  static Stream<QuerySnapshot> getActiveTokensForUser(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('fcmTokens')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }
}

