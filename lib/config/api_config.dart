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
  static String get authMe => '$baseUrl/auth/me';
  static String get authSocialLogin => '$baseUrl/auth/social-login';
  static String get authDeleteAccount => '$baseUrl/auth/delete-account';
  static String get authCheckUsername => '$baseUrl/auth/check-username';
  static String get authVerifyToken => '$baseUrl/auth/verify-token';
  static String get usersMe => '$baseUrl/users/me';
  static String userById(String userId) => '$baseUrl/users/$userId';
  static String get profileUpdate => '$baseUrl/profile/update';

  // EULA
  static String get eulaVersion => '$baseUrl/eula/version';
  static String get eulaStatus => '$baseUrl/eula/status';
  static String get eulaAccept => '$baseUrl/eula/accept';

  // Devices & FCM
  static String get devices => '$baseUrl/devices';
  static String deviceActive(String deviceId) =>
      '$baseUrl/devices/$deviceId/active';
  static String get fcmTokens => '$baseUrl/fcm-tokens';
  static String fcmTokenActive(String tokenId) =>
      '$baseUrl/fcm-tokens/$tokenId/active';

  // Config
  static String get configTagLists => '$baseUrl/config/tag-lists';

  // Wardrobes
  static String get wardrobes => '$baseUrl/wardrobes';
  static String wardrobe(String id) => '$baseUrl/wardrobes/$id';
  static String userWardrobes(String userId) => '$baseUrl/users/$userId/wardrobes';
  static String wardrobeClothes(String wardrobeId) =>
      '$baseUrl/wardrobes/$wardrobeId/clothes';

  // Clothes
  static String get clothes => '$baseUrl/clothes';
  static String get clothesDetect => '$baseUrl/clothes/detect';
  static String get clothesExtract => '$baseUrl/clothes/extract';
  static String get clothesUpload => '$baseUrl/clothes/upload';
  static String cloth(String clothId) => '$baseUrl/clothes/$clothId';
  static String clothLikes(String clothId) => '$baseUrl/clothes/$clothId/likes';
  static String clothWearHistory(String clothId) =>
      '$baseUrl/clothes/$clothId/wear-history';
  static String wearHistoryEntry(String entryId) =>
      '$baseUrl/wear-history/$entryId';
  static String get avatarDelete => '$baseUrl/avatar/me';

  // Chats & messages
  static String get chats => '$baseUrl/chats';
  static String chat(String chatId) => '$baseUrl/chats/$chatId';
  static String chatMessages(String chatId) => '$baseUrl/chats/$chatId/messages';
  static String messageSeen(String messageId) =>
      '$baseUrl/messages/$messageId/seen';
  static String messageDelete(String messageId) =>
      '$baseUrl/messages/$messageId';
  static String clothShare(String clothId) => '$baseUrl/clothes/$clothId/share';

  // API Endpoints
  static String get avatarGenerate => '$baseUrl/avatar/generate';
  static String get avatarMe => '$baseUrl/avatar/me';
  static String avatarStatus(String avatarId) => '$baseUrl/avatar/status/$avatarId';
  static String avatarRetry(String avatarId) => '$baseUrl/avatar/$avatarId/retry';

  static String get tryOnRender => '$baseUrl/try-on/render';
  static String tryOnStatus(String resultId) => '$baseUrl/try-on/status/$resultId';

  // Request timeout
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // Polling interval for async jobs
  static const Duration pollingInterval = Duration(seconds: 2);
  
  // Max polling attempts
  static const int maxPollingAttempts = 150; // 5 minutes max wait
}
