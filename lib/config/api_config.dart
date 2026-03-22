/// API configuration for Laravel AI service
class ApiConfig {
  // Base URL for Laravel API
  // Set via environment variable: LARAVEL_API_URL
  // Default for development
  static String get baseUrl {
    const envUrl = String.fromEnvironment('LARAVEL_API_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    // Default development URL - update in .env
    return 'https://api.wardrobe-app.com/v1';
  }

  // API Key for authentication
  // Set via environment variable: LARAVEL_API_KEY
  static String? get apiKey {
    const envKey = String.fromEnvironment('LARAVEL_API_KEY');
    return envKey.isNotEmpty ? envKey : null;
  }

  // API Endpoints
  static String get avatarGenerate => '$baseUrl/avatar/generate';
  static String avatarGet(String userId) => '$baseUrl/avatar/$userId';
  static String avatarRegenerate(String userId) => '$baseUrl/avatar/$userId/regenerate';
  static String avatarDelete(String userId) => '$baseUrl/avatar/$userId';
  
  // 3D Avatar Generation Endpoints
  static String get generate3DAvatar => '$baseUrl/avatar/generate-3d';
  static String get applyClothing => '$baseUrl/avatar/apply-clothing';
  static String getAvatarModel(String userId) => '$baseUrl/avatar/$userId/model';
  static String getRenderedOutfit(String outfitId) => '$baseUrl/outfit/$outfitId/rendered';
  
  static String get tryOnRender => '$baseUrl/try-on/render';
  static String get outfitRender => '$baseUrl/outfit/render';
  
  // Status polling endpoint
  static String jobStatus(String jobId) => '$baseUrl/jobs/$jobId/status';

  // Request timeout
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // Polling interval for async jobs
  static const Duration pollingInterval = Duration(seconds: 2);
  
  // Max polling attempts
  static const int maxPollingAttempts = 150; // 5 minutes max wait
}
