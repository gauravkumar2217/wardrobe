import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/user_profile.dart';
import 'laravel_api_client.dart';
import 'laravel_auth_service.dart';
import '../models/body_profile.dart';
import '../models/avatar.dart';
import '../models/eula_acceptance.dart';

/// User service — Laravel API (MySQL). No Firestore writes.
class UserService {

  /// Get user profile
  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final currentId = await LaravelAuthService.getCurrentUserId();
      if (currentId == userId) {
        return await LaravelAuthService.fetchUserProfile();
      }
      final body = await LaravelApiClient.getJson(ApiConfig.userById(userId));
      final data = LaravelApiClient.extractData(body);
      if (data is Map<String, dynamic>) {
        return _profileFromApi(data);
      }
    } catch (e) {
      debugPrint('Laravel profile fetch failed for $userId: $e');
    }
    return null;
  }

  /// Create or update user profile
  static Future<void> createOrUpdateProfile({
    required String userId,
    required UserProfile profile,
  }) async {
    final currentId = await LaravelAuthService.getCurrentUserId();
    if (currentId != userId) {
      throw Exception('Cannot update another user profile');
    }
    await LaravelAuthService.updateUserProfile(profile: profile);
  }

  /// Update user profile (partial update)
  static Future<void> updateProfile({
    required String userId,
    Map<String, dynamic>? updates,
    UserProfile? profile,
  }) async {
    final currentId = await LaravelAuthService.getCurrentUserId();
    if (currentId != userId) {
      throw Exception('Cannot update another user profile');
    }
    if (profile != null) {
      await LaravelAuthService.updateUserProfile(profile: profile);
      return;
    }
    if (updates == null || updates.isEmpty) return;

    final existing = await LaravelAuthService.fetchUserProfile();
    final merged = (existing ?? UserProfile()).copyWith(
      displayName: updates['displayName'] as String? ?? updates['display_name'] as String?,
      username: updates['username'] as String?,
      photoUrl: updates['photoUrl'] as String? ?? updates['photo_url'] as String?,
      email: updates['email'] as String?,
      phone: updates['phone'] as String?,
      gender: updates['gender'] as String?,
    );
    await LaravelAuthService.updateUserProfile(profile: merged);
  }

  /// Update notification settings
  static Future<void> updateNotificationSettings({
    required String userId,
    required NotificationSettings settings,
  }) async {
    try {
      final profile = await _loadProfileForSettings(userId);
      final merged = UserSettings(
        notifications: settings,
        privacy: profile.settings?.privacy ?? PrivacySettings(),
      );
      await LaravelAuthService.updateUserProfile(
        profile: profile.copyWith(settings: merged),
      );
    } catch (e) {
      debugPrint('Failed to update notification settings: $e');
      rethrow;
    }
  }

  /// Update privacy settings
  static Future<void> updatePrivacySettings({
    required String userId,
    required PrivacySettings privacy,
  }) async {
    try {
      final profile = await _loadProfileForSettings(userId);
      final merged = UserSettings(
        notifications: profile.settings?.notifications ?? NotificationSettings(),
        privacy: privacy,
      );
      await LaravelAuthService.updateUserProfile(
        profile: profile.copyWith(settings: merged),
      );
    } catch (e) {
      debugPrint('Failed to update privacy settings: $e');
      rethrow;
    }
  }

  static Future<UserProfile> _loadProfileForSettings(String userId) async {
    final currentId = await LaravelAuthService.getCurrentUserId();
    if (currentId == null || currentId != userId) {
      throw Exception('Cannot update settings for this user');
    }
    final profile = await LaravelAuthService.fetchUserProfile();
    if (profile == null) {
      throw Exception('Could not load user profile');
    }
    return profile;
  }

  /// Find user profile by email (Laravel API).
  static Future<String?> findUserIdByEmail(String email) async {
    try {
      if (email.isEmpty) return null;
      final uri = Uri.parse(ApiConfig.usersSearch).replace(
        queryParameters: {'query': email.trim().toLowerCase()},
      );
      final body = await LaravelApiClient.getJson(uri.toString());
      final data = LaravelApiClient.extractData(body);
      final list = data is List
          ? data
          : (data is Map<String, dynamic> && data['data'] is List)
              ? data['data'] as List
              : <dynamic>[];
      final normalized = email.trim().toLowerCase();
      for (final item in list) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final itemEmail =
            (map['email'] as String?)?.trim().toLowerCase();
        if (itemEmail == normalized) {
          return map['id']?.toString();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Failed to find user by email: $e');
      return null;
    }
  }

  /// Search users by name, username, email, or phone
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final normalizedQuery = query.trim();
      if (normalizedQuery.isEmpty) return [];

      final uri = Uri.parse(ApiConfig.usersSearch).replace(
        queryParameters: {'query': normalizedQuery},
      );
      final body = await LaravelApiClient.getJson(uri.toString());
      final data = LaravelApiClient.extractData(body);
      final list = data is List
          ? data
          : (data is Map<String, dynamic> && data['data'] is List)
              ? data['data'] as List
              : <dynamic>[];

      return list.whereType<Map>().map((raw) {
        final item = Map<String, dynamic>.from(raw);
        return {
          'userId': item['id']?.toString(),
          'displayName':
              item['display_name'] as String? ?? item['displayName'] as String?,
          'username': item['username'] as String?,
          'photoUrl':
              item['photo_url'] as String? ?? item['photoUrl'] as String?,
          'email': item['email'] as String?,
          'phone': item['phone'] as String?,
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to search users: $e');
      return [];
    }
  }

  /// Get user by ID (public info only)
  static Future<Map<String, dynamic>?> getUserPublicInfo(String userId) async {
    try {
      final profile = await getUserProfile(userId);
      if (profile == null) return null;
      return {
        'userId': userId,
        'displayName': profile.displayName,
        'photoUrl': profile.photoUrl,
      };
    } catch (e) {
      debugPrint('Failed to get user public info: $e');
      return null;
    }
  }

  /// Delete user account
  static Future<void> deleteAccount(String userId) async {
    final currentId = await LaravelAuthService.getCurrentUserId();
    if (currentId != userId) {
      throw Exception('Cannot delete another user account');
    }
    await LaravelAuthService.deleteAccount();
  }

  /// Poll user profile for updates (replaces Firestore snapshots).
  static Stream<UserProfile?> watchUserProfile(String userId) async* {
    yield await getUserProfile(userId);
    while (true) {
      await Future.delayed(const Duration(seconds: 30));
      yield await getUserProfile(userId);
    }
  }

  /// Check if username is available (Laravel API).
  static Future<bool> isUsernameAvailable(String username) async {
    try {
      return await LaravelAuthService.isUsernameAvailable(username);
    } catch (e) {
      debugPrint('Failed to check username availability: $e');
      return false;
    }
  }

  /// Deprecated: login uses Laravel username directly.
  static Future<String?> getEmailByUsername(String username) async {
    return null;
  }

  /// Record EULA acceptance via Laravel API.
  static Future<void> recordEulaAcceptance({
    required String userId,
    required String version,
    String? ipAddress,
  }) async {
    try {
      final body = await LaravelApiClient.postJson(
        ApiConfig.eulaAccept,
        {
          'version': version,
          if (ipAddress != null) 'ip_address': ipAddress,
        },
      );
      LaravelApiClient.extractData(body);
    } catch (e) {
      debugPrint('Failed to record EULA acceptance: $e');
      rethrow;
    }
  }

  /// Check if user has accepted the current EULA version.
  static Future<bool> hasAcceptedEula(String userId) async {
    try {
      final body = await LaravelApiClient.getJson(ApiConfig.eulaStatus);
      final data = LaravelApiClient.extractData(body);
      if (data is Map<String, dynamic>) {
        return data['accepted'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to check EULA acceptance: $e');
      return false;
    }
  }

  /// Get latest EULA acceptance from Laravel API.
  static Future<EulaAcceptance?> getLatestEulaAcceptance(String userId) async {
    try {
      final body = await LaravelApiClient.getJson(ApiConfig.eulaStatus);
      final data = LaravelApiClient.extractData(body);
      if (data is Map<String, dynamic>) {
        final latest = data['latest'];
        if (latest is Map<String, dynamic>) {
          return EulaAcceptance.fromApiJson(latest);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get latest EULA acceptance: $e');
      return null;
    }
  }

  /// Get current EULA version from Laravel API.
  static Future<String> getCurrentEulaVersion() async {
    try {
      final body = await LaravelApiClient.getPublicJson(ApiConfig.eulaVersion);
      final data = LaravelApiClient.extractData(body);
      if (data is Map<String, dynamic>) {
        return data['version']?.toString() ?? '1.0';
      }
    } catch (e) {
      debugPrint('Failed to fetch EULA version: $e');
    }
    return '1.0';
  }

  static UserProfile _profileFromApi(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    UserSettings? settings;
    final settingsRaw = json['settings'];
    if (settingsRaw is Map<String, dynamic>) {
      settings = UserSettings.fromJson(settingsRaw);
    }

    return UserProfile(
      displayName: json['display_name'] as String? ?? json['displayName'] as String?,
      username: json['username'] as String?,
      photoUrl: json['photo_url'] as String? ?? json['photoUrl'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String? ?? json['phone_number'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: parseDate(json['date_of_birth'] ?? json['dateOfBirth']),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDate(json['updated_at'] ?? json['updatedAt']),
      settings: settings,
    );
  }

  static Future<Map<String, dynamic>?> _rawSettings(String userId) async {
    final currentId = await LaravelAuthService.getCurrentUserId();
    if (currentId != userId) return null;
    final body = await LaravelApiClient.getJson(ApiConfig.usersMe);
    final data = LaravelApiClient.extractData(body);
    if (data is Map<String, dynamic> && data['settings'] is Map) {
      return Map<String, dynamic>.from(data['settings'] as Map);
    }
    return null;
  }

  /// Get body profile for user (stored in Laravel settings JSON).
  static Future<BodyProfile?> getBodyProfile(String userId) async {
    try {
      final settings = await _rawSettings(userId);
      final raw = settings?['bodyProfile'];
      if (raw is Map<String, dynamic>) {
        return BodyProfile.fromApiJson(raw, userId);
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get body profile: $e');
      return null;
    }
  }

  /// Save or update body profile
  static Future<void> saveBodyProfile(BodyProfile bodyProfile) async {
    try {
      await LaravelApiClient.putJson(ApiConfig.profileUpdate, {
        'settings': {
          'bodyProfile': bodyProfile.toApiJson(),
        },
      });
      debugPrint(
          'Body profile saved via Laravel for user ${bodyProfile.userId}');
    } catch (e) {
      debugPrint('Failed to save body profile: $e');
      rethrow;
    }
  }

  /// Delete body profile
  static Future<void> deleteBodyProfile(String userId) async {
    try {
      await LaravelApiClient.putJson(ApiConfig.profileUpdate, {
        'settings': {'bodyProfile': null},
      });
      debugPrint('Body profile deleted via Laravel for user $userId');
    } catch (e) {
      debugPrint('Failed to delete body profile: $e');
      rethrow;
    }
  }

  /// Get avatar for user
  static Future<Avatar?> getAvatar(String userId) async {
    try {
      final currentId = await LaravelAuthService.getCurrentUserId();
      if (currentId != userId) {
        return null;
      }

      final body = await LaravelApiClient.getJson(ApiConfig.avatarMe);
      final data = LaravelApiClient.extractData(body);
      if (data is Map<String, dynamic>) {
        return Avatar.fromApiJson(data, userId);
      }
      return null;
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('404') || message.contains('not found')) {
        return null;
      }
      debugPrint('Failed to get avatar: $e');
      return null;
    }
  }

  /// Avatar is persisted by Laravel during generation; kept for API compatibility.
  static Future<void> saveAvatar(Avatar avatar) async {
    if (kDebugMode) {
      debugPrint('Avatar stored in Laravel for user ${avatar.userId}');
    }
  }

  /// Delete avatar
  static Future<void> deleteAvatar(String userId) async {
    try {
      await LaravelApiClient.deleteJson(ApiConfig.avatarDelete);
      if (kDebugMode) {
        debugPrint('Avatar deleted successfully for user $userId');
      }
    } catch (e) {
      debugPrint('Failed to delete avatar: $e');
      rethrow;
    }
  }
}
