import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/app_user.dart';
import '../models/user_profile.dart';
import 'secure_token_storage.dart';

/// Laravel Sanctum authentication (register, login, social, token, user profile).
class LaravelAuthService {
  static String? _memoryUserId;

  static String? get memoryUserId => _memoryUserId;

  static Future<String?> getCachedToken() => SecureTokenStorage.readToken();

  static Future<AppUser?> getCachedUser() async {
    final json = await SecureTokenStorage.readUserJson();
    if (json == null) return null;
    try {
      final user = AppUser.fromJson(json);
      return user.id.isNotEmpty ? user : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _persistSession({
    required String token,
    required AppUser user,
  }) async {
    _memoryUserId = user.id;
    await SecureTokenStorage.writeSession(
      token: token,
      userJson: user.toJson(),
    );
  }

  static Future<void> clearToken() async {
    _memoryUserId = null;
    await SecureTokenStorage.clear();
  }

  static Future<String?> getCurrentUserId() async {
    final user = await getCachedUser();
    return user?.id;
  }

  static Future<String> ensureToken({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await getCachedToken();
      if (cached != null) return cached;
    }
    throw Exception('Not authenticated. Please sign in again.');
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
    } catch (_) {}
    throw Exception(
      'Invalid server response (${response.statusCode}): ${response.body}',
    );
  }

  static void _throwApiError(Map<String, dynamic> body, int statusCode) {
    final message = body['message']?.toString() ?? 'Request failed';
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        throw Exception(first.first.toString());
      }
    }
    throw Exception('$message ($statusCode)');
  }

  static Future<({String token, AppUser user})> register({
    required String email,
    required String password,
    String? displayName,
    String? username,
  }) async {
    final uri = Uri.parse(ApiConfig.authRegister);
    final payload = <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'password': password,
      if (displayName != null && displayName.trim().isNotEmpty)
        'display_name': displayName.trim(),
      if (username != null && username.trim().isNotEmpty)
        'username': username.trim().toLowerCase(),
    };

    final response = await http
        .post(
          uri,
          headers: _publicHeaders,
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.requestTimeout);

    final body = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(body, response.statusCode);
    }
    return _parseAuthResponse(body);
  }

  static Future<({String token, AppUser user})> login({
    String? login,
    String? email,
    String? username,
    required String password,
  }) async {
    final identifier = (login ?? username ?? email ?? '').trim().toLowerCase();
    if (identifier.isEmpty) {
      throw Exception('Email or username is required');
    }

    final uri = Uri.parse(ApiConfig.authLogin);
    final payload = <String, dynamic>{
      'login': identifier,
      'password': password,
    };

    final response = await http
        .post(
          uri,
          headers: _publicHeaders,
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.requestTimeout);

    final body = _decodeResponse(response);
    if (response.statusCode == 401 || response.statusCode == 403) {
      _throwApiError(body, response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(body, response.statusCode);
    }
    return _parseAuthResponse(body);
  }

  /// Social login (Google / Apple) via Laravel API.
  static Future<({String token, AppUser user})> socialLogin({
    required String provider,
    required String providerId,
    String? idToken,
    String? email,
    String? firstName,
    String? lastName,
    String? avatar,
    String? displayName,
  }) async {
    final payload = <String, dynamic>{
      'provider': provider,
      'provider_id': providerId,
      if (idToken != null && idToken.isNotEmpty) 'id_token': idToken,
      if (email != null && email.isNotEmpty) 'email': email.trim().toLowerCase(),
      if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
      if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
      if (avatar != null && avatar.isNotEmpty) 'avatar': avatar,
      if (displayName != null && displayName.isNotEmpty)
        'display_name': displayName,
    };

    final response = await http
        .post(
          Uri.parse(ApiConfig.authSocialLogin),
          headers: _publicHeaders,
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.requestTimeout);

    final body = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(body, response.statusCode);
    }
    return _parseAuthResponse(body);
  }

  static Future<({String token, AppUser user})> _parseAuthResponse(
    Map<String, dynamic> body,
  ) async {
    if (body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'Authentication failed');
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid authentication response');
    }
    final token = data['token']?.toString();
    final userJson = data['user'];
    if (token == null || token.trim().isEmpty) {
      throw Exception('Authentication token missing');
    }
    if (userJson is! Map<String, dynamic>) {
      throw Exception('User data missing');
    }
    final user = AppUser.fromJson(userJson);
    if (user.id.isEmpty) {
      throw Exception('User id missing');
    }
    await _persistSession(token: token, user: user);
    if (kDebugMode) {
      debugPrint('✅ Laravel session established for ${user.id}');
    }
    return (token: token.trim(), user: user);
  }

  /// Restore session from API using cached token.
  static Future<AppUser?> restoreSession() async {
    final cachedUser = await getCachedUser();
    _memoryUserId = cachedUser?.id;
    final token = await getCachedToken();
    if (token == null) return null;
    try {
      return await fetchCurrentUser(token: token);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Session restore failed: $e');
      }
      await clearToken();
      return null;
    }
  }

  static Future<AppUser> fetchCurrentUser({String? token}) async {
    final authToken = token ?? await ensureToken();
    final response = await http
        .get(
          Uri.parse(ApiConfig.authMe),
          headers: _authHeaders(authToken),
        )
        .timeout(ApiConfig.requestTimeout);

    final body = _decodeResponse(response);
    if (response.statusCode == 401) {
      await clearToken();
      throw Exception('Session expired. Please sign in again.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(body, response.statusCode);
    }
    if (body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'Failed to load user');
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid user response');
    }
    final user = AppUser.fromJson(data);
    await _persistSession(token: authToken, user: user);
    return user;
  }

  static Future<UserProfile?> fetchUserProfile({String? token}) async {
    final authToken = token ?? await ensureToken();
    final response = await http
        .get(
          Uri.parse(ApiConfig.usersMe),
          headers: _authHeaders(authToken),
        )
        .timeout(ApiConfig.requestTimeout);

    final body = _decodeResponse(response);
    if (response.statusCode == 401) {
      await clearToken();
      throw Exception('Session expired. Please sign in again.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(body, response.statusCode);
    }
    if (body['success'] != true) return null;
    final data = body['data'];
    if (data is! Map<String, dynamic>) return null;
    return _userProfileFromApi(data);
  }

  static Future<UserProfile> updateUserProfile({
    required UserProfile profile,
    String? token,
  }) async {
    final authToken = token ?? await ensureToken();
    final payload = <String, dynamic>{};
    if (profile.displayName != null) {
      payload['display_name'] = profile.displayName;
    }
    if (profile.username != null) {
      payload['username'] = profile.username!.toLowerCase();
    }
    if (profile.photoUrl != null) payload['photo_url'] = profile.photoUrl;
    if (profile.email != null) payload['email'] = profile.email;
    if (profile.phone != null) payload['phone'] = profile.phone;
    if (profile.gender != null) payload['gender'] = profile.gender;
    if (profile.dateOfBirth != null) {
      payload['date_of_birth'] =
          profile.dateOfBirth!.toIso8601String().split('T').first;
    }
    if (profile.settings != null) {
      payload['settings'] = profile.settings!.toJson();
    }

    final response = await http
        .put(
          Uri.parse(ApiConfig.profileUpdate),
          headers: _authHeaders(authToken),
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.requestTimeout);

    final body = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(body, response.statusCode);
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid profile update response');
    }
    return _userProfileFromApi(data);
  }

  static Future<bool> isUsernameAvailable(String username) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.length < 3) return false;

    final uri = Uri.parse(ApiConfig.authCheckUsername).replace(
      queryParameters: {'username': normalized},
    );
    final response = await http
        .get(uri, headers: _publicHeaders)
        .timeout(ApiConfig.requestTimeout);

    final body = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return data['available'] == true;
    }
    return false;
  }

  static Future<void> deleteAccount() async {
    final token = await ensureToken();
    final response = await http
        .delete(
          Uri.parse(ApiConfig.authDeleteAccount),
          headers: _authHeaders(token),
        )
        .timeout(ApiConfig.requestTimeout);

    final body = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(body, response.statusCode);
    }
    await clearToken();
  }

  static UserProfile _userProfileFromApi(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
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

  static Future<void> logout() async {
    final token = await getCachedToken();
    if (token != null) {
      try {
        await http
            .post(
              Uri.parse(ApiConfig.authLogout),
              headers: _authHeaders(token),
            )
            .timeout(ApiConfig.requestTimeout);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Laravel logout request failed (ignored): $e');
        }
      }
    }
    await clearToken();
  }

  static const _publicHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, String> _authHeaders(String token) => {
        ..._publicHeaders,
        'Authorization': 'Bearer $token',
      };
}
