import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'fcm_token_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if user is currently logged in
  static Future<bool> isUserLoggedIn() async {
    final user = _auth.currentUser;
    return user != null;
  }

  /// Get current user
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Sign out user
  /// All operations have timeouts to prevent the app from getting stuck
  static Future<void> signOut() async {
    // Capture user info BEFORE signing out
    final user = _auth.currentUser;
    final userId = user?.uid;
    final token = FCMTokenService.getCurrentToken();

    // If user is not authenticated and token is not available,
    // user is already logged out - nothing to do
    if (user == null && token == null) {
      debugPrint('User already logged out, skipping sign out operations');
      return;
    }

    // Deactivate FCM token before signing out (using captured info)
    // This ensures push notifications won't be sent to logged out users
    // Only attempt if we have both userId and token
    if (userId != null && token != null) {
      try {
        await FCMTokenService.deactivateToken(userId, token)
            .timeout(const Duration(seconds: 3));
      } on TimeoutException {
        debugPrint('FCM token deactivation timed out, continuing sign out');
      } catch (e) {
        // Log error but don't block sign out
        debugPrint('Failed to deactivate FCM token on sign out: $e');
      }
    } else if (user != null) {
      // User is authenticated but token not available - try current user method
      // This handles edge cases where token wasn't initialized
      try {
        await FCMTokenService.deactivateTokenForCurrentUser()
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        // This is expected if token is not available - not an error
        debugPrint('FCM token not available for deactivation (non-critical)');
      }
    } else {
      // User is null but token exists - user already logged out
      debugPrint('User already logged out, skipping FCM token deactivation');
    }

    // Sign out from Firebase with timeout (only if user is still authenticated)
    if (user != null) {
      try {
        await _auth.signOut().timeout(const Duration(seconds: 5));
      } on TimeoutException {
        debugPrint('Firebase signOut timed out, continuing');
      } catch (e) {
        debugPrint('Error during Firebase signOut: $e');
        // Continue anyway - user should still be signed out
      }
    }

    // Clear any stored user data with timeout
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      debugPrint('SharedPreferences clear timed out');
    } catch (e) {
      debugPrint('Failed to clear SharedPreferences: $e');
      // Don't block - this is not critical
    }
  }

  /// Get user phone number
  static String? getUserPhoneNumber() {
    return _auth.currentUser?.phoneNumber;
  }

  /// Get user UID
  static String? getUserUID() {
    return _auth.currentUser?.uid;
  }

  /// Listen to auth state changes
  static Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }
}
