import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'auth_service.dart';
import 'laravel_auth_service.dart';

/// Bridges Google/Apple Firebase sign-in to Laravel Sanctum session.
class SocialAuthBridge {
  static Future<({String token, AppUser user})> signInWithGoogle() async {
    return _exchangeFirebaseSession(
      provider: 'google',
      signIn: AuthService.signInWithGoogle,
    );
  }

  static Future<({String token, AppUser user})> signInWithApple() async {
    return _exchangeFirebaseSession(
      provider: 'apple',
      signIn: AuthService.signInWithApple,
    );
  }

  static Future<({String token, AppUser user})> _exchangeFirebaseSession({
    required String provider,
    required Future<UserCredential> Function() signIn,
  }) async {
    UserCredential? credential;
    try {
      credential = await signIn();
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('Sign-in failed: no user returned');
      }

      final idToken = await firebaseUser.getIdToken();
      final (firstName, lastName) = _splitName(firebaseUser.displayName);

      final session = await LaravelAuthService.socialLogin(
        provider: provider,
        providerId: firebaseUser.uid,
        idToken: idToken,
        email: firebaseUser.email,
        firstName: firstName,
        lastName: lastName,
        avatar: firebaseUser.photoURL,
        displayName: firebaseUser.displayName,
      );

      return session;
    } finally {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Firebase sign-out after social login (ignored): $e');
        }
      }
    }
  }

  static (String?, String?) _splitName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) {
      return (null, null);
    }
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return (parts.first, null);
    }
    return (parts.first, parts.sublist(1).join(' '));
  }
}
