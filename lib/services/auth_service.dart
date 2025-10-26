import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static Future<void> signOut() async {
    await _auth.signOut();

    // Clear any stored user data
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
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
