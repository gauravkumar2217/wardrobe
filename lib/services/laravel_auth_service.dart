import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class LaravelAuthService {
  static const _tokenKey = 'laravel_sanctum_token';

  static Future<String?> getCachedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString(_tokenKey);
    return (t == null || t.trim().isEmpty) ? null : t.trim();
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Ensures a Sanctum token exists for the current Firebase user.
  /// Laravel backend currently trusts the Firebase UID (no server-side token verification).
  static Future<String> ensureToken() async {
    final cached = await getCachedToken();
    if (cached != null) return cached;
    return await verifyAndCreateToken();
  }

  static Future<String> verifyAndCreateToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated');
    }

    final uri = Uri.parse(ApiConfig.authVerifyToken);
    final payload = {
      'uid': user.uid,
      if (user.email != null) 'email': user.email,
      if (user.displayName != null) 'display_name': user.displayName,
      if (user.photoURL != null) 'photo_url': user.photoURL,
      if (user.phoneNumber != null) 'phone': user.phoneNumber,
    };

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.requestTimeout);

    final body = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Laravel auth failed (${response.statusCode}): ${response.body}',
      );
    }
    if (body is! Map<String, dynamic> || body['success'] != true) {
      throw Exception('Laravel auth failed: ${response.body}');
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Laravel auth: invalid response data');
    }
    final token = data['token']?.toString();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Laravel auth: token missing');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token.trim());

    if (kDebugMode) {
      debugPrint('✅ Laravel Sanctum token cached');
    }
    return token.trim();
  }
}

