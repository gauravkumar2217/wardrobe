import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API configuration for Laravel API service
class ApiConfig {
  // Base URL for Laravel API
  // Set via .env: LARAVEL_API_BASE_URL
  // Must include `/api` (Laravel routes/api.php).
  static String get baseUrl {
    const fallback = 'https://www.wardrobe.chat/api';
    try {
      if (!dotenv.isInitialized) return fallback;
      final v = dotenv.env['LARAVEL_API_BASE_URL']?.trim();
      if (v == null || v.isEmpty) return fallback;
      return v.endsWith('/') ? v.substring(0, v.length - 1) : v;
    } catch (_) {
      return fallback;
    }
  }

  // Auth endpoints (Laravel Sanctum)
  static String get authRegister => '$baseUrl/auth/register';
  static String get authLogin => '$baseUrl/auth/login';
  static String get authLogout => '$baseUrl/auth/logout';
  static String get authUser => '$baseUrl/auth/user';
  static String get authCheckUsername => '$baseUrl/auth/check-username';
  static String get authVerifyToken => '$baseUrl/auth/verify-token';
  static String get usersMe => '$baseUrl/users/me';

  // API Endpoints
  static String get avatarGenerate => '$baseUrl/avatar/generate';
  static String get avatarMe => '$baseUrl/avatar/me';
  static String avatarStatus(String avatarId) => '$baseUrl/avatar/status/$avatarId';

  static String get tryOnRender => '$baseUrl/try-on/render';
  static String tryOnStatus(String resultId) => '$baseUrl/try-on/status/$resultId';

  // Request timeout
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // Polling interval for async jobs
  static const Duration pollingInterval = Duration(seconds: 2);
  
  // Max polling attempts
  static const int maxPollingAttempts = 150; // 5 minutes max wait
}
