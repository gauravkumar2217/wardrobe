import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'laravel_api_client.dart';

/// Onboarding flags stored in Laravel `users.settings` JSON.
class OnboardingService {
  static Map<String, dynamic>? _settingsFromProfile(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final settings = data['settings'];
    if (settings is Map<String, dynamic>) return settings;
    return null;
  }

  static Future<Map<String, dynamic>> _fetchSettings() async {
    final body = await LaravelApiClient.getJson(ApiConfig.usersMe);
    final data = LaravelApiClient.extractData(body);
    return _settingsFromProfile(data) ?? {};
  }

  static Future<void> _patchSettings(Map<String, dynamic> patch) async {
    await LaravelApiClient.putJson(ApiConfig.profileUpdate, {
      'settings': patch,
    });
  }

  static Future<bool> hasCompletedOnboarding(String userId) async {
    try {
      final settings = await _fetchSettings();
      return settings['onboardingCompleted'] == true;
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
      return false;
    }
  }

  static Future<void> completeOnboarding(String userId) async {
    try {
      await _patchSettings({'onboardingCompleted': true});
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      rethrow;
    }
  }

  static Future<void> skipOnboarding(String userId) async {
    try {
      await _patchSettings({
        'onboardingCompleted': true,
        'onboardingSkipped': true,
      });
    } catch (e) {
      debugPrint('Error skipping onboarding: $e');
      rethrow;
    }
  }

  static Future<void> resetOnboarding(String userId) async {
    try {
      await _patchSettings({
        'onboardingCompleted': false,
        'onboardingSkipped': false,
      });
    } catch (e) {
      debugPrint('Error resetting onboarding: $e');
      rethrow;
    }
  }
}
