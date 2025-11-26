import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'fcm_service.dart';

/// Authentication service supporting Phone, Google, and Email/Password
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Get current user
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Check if user is logged in
  static bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }

  /// Get user UID
  static String? getUserUID() {
    return _auth.currentUser?.uid;
  }

  /// Get user email
  static String? getUserEmail() {
    return _auth.currentUser?.email;
  }

  /// Get user phone number
  static String? getUserPhoneNumber() {
    return _auth.currentUser?.phoneNumber;
  }

  /// Get user display name
  static String? getUserDisplayName() {
    return _auth.currentUser?.displayName;
  }

  /// Get user photo URL
  static String? getUserPhotoURL() {
    return _auth.currentUser?.photoURL;
  }

  /// Sign in with phone number (OTP)
  static Future<UserCredential> signInWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      
      // Register FCM token after successful login
      if (userCredential.user != null) {
        await FCMService.registerDeviceToken(userCredential.user!.uid);
      }

      return userCredential;
    } catch (e) {
      debugPrint('Phone sign-in error: $e');
      rethrow;
    }
  }

  /// Send OTP to phone number
  static Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseAuthException error) onError,
    Function(PhoneAuthCredential credential)? onVerificationCompleted,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: onVerificationCompleted ?? (credential) {},
        verificationFailed: onError,
        codeSent: (verificationId, resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (verificationId) {},
      );
    } catch (e) {
      onError(FirebaseAuthException(code: 'unknown', message: e.toString()));
    }
  }

  /// Sign in with Google
  static Future<UserCredential> signInWithGoogle() async {
    try {
      // Sign out any existing Google account
      await _googleSignIn.signOut();

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google sign-in was canceled');
      }

      // Obtain the auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Validate tokens
      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        throw Exception('Failed to get authentication tokens');
      }

      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);

      // Register FCM token after successful login
      if (userCredential.user != null) {
        await FCMService.registerDeviceToken(userCredential.user!.uid);
      }

      return userCredential;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Register FCM token after successful login
      if (userCredential.user != null) {
        await FCMService.registerDeviceToken(userCredential.user!.uid);
      }

      return userCredential;
    } catch (e) {
      debugPrint('Email sign-in error: $e');
      rethrow;
    }
  }

  /// Register with email and password
  static Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Register FCM token after successful registration
      if (userCredential.user != null) {
        await FCMService.registerDeviceToken(userCredential.user!.uid);
      }

      return userCredential;
    } catch (e) {
      debugPrint('Email registration error: $e');
      rethrow;
    }
  }

  /// Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Password reset error: $e');
      rethrow;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      
      // Deactivate FCM token before signing out
      if (user != null) {
        await FCMService.deactivateDeviceToken(user.uid);
      }

      // Sign out from Google if signed in
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      // Sign out from Firebase
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  /// Listen to auth state changes
  static Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  /// Update user profile
  static Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
      await _auth.currentUser?.updatePhotoURL(photoURL);
      await _auth.currentUser?.reload();
    } catch (e) {
      debugPrint('Update profile error: $e');
      rethrow;
    }
  }
}

