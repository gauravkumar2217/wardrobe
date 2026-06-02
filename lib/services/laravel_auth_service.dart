import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Exchanges a verified Firebase ID token for a Laravel Sanctum API token.
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

  /// Returns a cached Sanctum token, or verifies Firebase and creates one.
  static Future<String> ensureToken({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await getCachedToken();
      if (cached != null) return cached;
    }
    return await verifyAndCreateToken();
  }

  /// Verifies the current user's Firebase ID token with Laravel and caches Sanctum token.
  static Future<String> verifyAndCreateToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated with Firebase');
    }

    final idToken = await user.getIdToken(true);

    final uri = Uri.parse(ApiConfig.authVerifyToken);
    final payload = <String, dynamic>{
      'id_token': idToken,
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

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'Laravel auth returned invalid JSON (${response.statusCode})',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(
        body['message']?.toString() ?? 'Firebase token rejected by server',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Laravel auth failed (${response.statusCode}): ${response.body}',
      );
    }
    if (body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'Laravel auth failed');
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Laravel auth: invalid response data');
    }
    final token = data['token']?.toString();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Laravel auth: Sanctum token missing');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token.trim());

    if (kDebugMode) {
      debugPrint('✅ Laravel Sanctum token issued after Firebase verification');
    }
    return token.trim();
  }

  /// Call Laravel logout and clear cached Sanctum token.
  static Future<void> logout() async {
    final token = await getCachedToken();
    if (token != null) {
      try {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(ApiConfig.requestTimeout);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Laravel logout request failed (ignored): $e');
        }
      }
    }
    await clearToken();
  }
}
