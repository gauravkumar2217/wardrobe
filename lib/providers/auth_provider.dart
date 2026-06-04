import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../models/user_profile.dart';
import '../services/fcm_service.dart';
import '../services/laravel_auth_service.dart';
import '../services/user_service.dart';

/// Auth provider backed by Laravel API (Sanctum token).
class AuthProvider with ChangeNotifier {
  AppUser? _user;
  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  AppUser? get user => _user;
  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      final restored = await LaravelAuthService.restoreSession();
      if (restored != null) {
        _user = restored;
        await _loadUserProfile();
        try {
          await FCMService.registerDeviceToken(_user!.uid);
        } catch (e) {
          debugPrint('Failed to register FCM token on init: $e');
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize auth: $e';
    } finally {
      _isLoading = false;
      _isInitialized = true;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<void> _loadUserProfile() async {
    if (_user == null) return;
    try {
      _userProfile = await LaravelAuthService.fetchUserProfile();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load user profile from API: $e');
      try {
        _userProfile = await UserService.getUserProfile(_user!.uid);
        notifyListeners();
      } catch (firestoreError) {
        debugPrint('Failed to load user profile from Firestore: $firestoreError');
      }
    }
  }

  Future<bool> signInWithUsername({
    required String username,
    required String password,
  }) async {
    return _signIn(
      login: username.trim().toLowerCase(),
      password: password,
      invalidCredentialsMessage: 'Incorrect username or password.',
    );
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _signIn(
      login: email.trim().toLowerCase(),
      password: password,
      invalidCredentialsMessage: 'Incorrect email or password.',
    );
  }

  Future<bool> _signIn({
    required String login,
    required String password,
    required String invalidCredentialsMessage,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await LaravelAuthService.login(
        login: login,
        password: password,
      );
      _user = session.user;
      await _loadUserProfile();
      try {
        await FCMService.registerDeviceToken(_user!.uid);
      } catch (e) {
        debugPrint('Failed to register FCM token after sign-in: $e');
      }
      _errorMessage = null;
      return true;
    } catch (e) {
      final message = e.toString();
      if (message.contains('401') ||
          message.toLowerCase().contains('invalid credentials')) {
        _errorMessage = invalidCredentialsMessage;
      } else {
        _errorMessage = message.replaceFirst('Exception: ', '');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
    String? username,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await LaravelAuthService.register(
        email: email,
        password: password,
        displayName: displayName,
        username: username,
      );
      _user = session.user;
      await _loadUserProfile();
      try {
        await FCMService.registerDeviceToken(_user!.uid);
      } catch (e) {
        debugPrint('Failed to register FCM token after registration: $e');
      }
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Social / phone sign-in is no longer used; kept for API compatibility.
  Future<bool> signInWithGoogle() async {
    _errorMessage = 'Google sign-in is disabled. Please use email and password.';
    notifyListeners();
    return false;
  }

  Future<bool> signInWithApple() async {
    _errorMessage = 'Apple sign-in is disabled. Please use email and password.';
    notifyListeners();
    return false;
  }

  Future<bool> signInWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String smsCode,
  }) async {
    _errorMessage = 'Phone sign-in is disabled. Please use email and password.';
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = null;
      _userProfile = null;
      _errorMessage = null;
      notifyListeners();
      await LaravelAuthService.logout();
    } catch (e) {
      _errorMessage = 'Failed to sign out: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    if (_user == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _userProfile = await LaravelAuthService.updateUserProfile(profile: profile);
      await UserService.createOrUpdateProfile(
        userId: _user!.uid,
        profile: _userProfile!,
      );
      _errorMessage = null;
    } catch (e) {
      try {
        await UserService.createOrUpdateProfile(
          userId: _user!.uid,
          profile: profile,
        );
        _userProfile = profile;
        _errorMessage = null;
      } catch (firestoreError) {
        _errorMessage = 'Failed to update profile: $e';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    if (_user != null) {
      await _loadUserProfile();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
