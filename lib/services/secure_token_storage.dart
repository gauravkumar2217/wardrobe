import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage for Sanctum tokens and cached user JSON.
class SecureTokenStorage {
  static const _tokenKey = 'laravel_sanctum_token';
  static const _userKey = 'laravel_auth_user';

  // Legacy SharedPreferences keys (migrated on first read).
  static const _legacyTokenKey = 'laravel_sanctum_token';
  static const _legacyUserKey = 'laravel_auth_user';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<void> _migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_legacyTokenKey);
    final legacyUser = prefs.getString(_legacyUserKey);

    if (legacyToken != null && legacyToken.trim().isNotEmpty) {
      await _storage.write(key: _tokenKey, value: legacyToken.trim());
      await prefs.remove(_legacyTokenKey);
    }
    if (legacyUser != null && legacyUser.trim().isNotEmpty) {
      await _storage.write(key: _userKey, value: legacyUser);
      await prefs.remove(_legacyUserKey);
    }
  }

  static Future<String?> readToken() async {
    await _migrateFromSharedPreferences();
    final token = await _storage.read(key: _tokenKey);
    return (token == null || token.trim().isEmpty) ? null : token.trim();
  }

  static Future<Map<String, dynamic>?> readUserJson() async {
    await _migrateFromSharedPreferences();
    final raw = await _storage.read(key: _userKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  static Future<void> writeSession({
    required String token,
    required Map<String, dynamic> userJson,
  }) async {
    await _storage.write(key: _tokenKey, value: token.trim());
    await _storage.write(key: _userKey, value: jsonEncode(userJson));
  }

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyTokenKey);
    await prefs.remove(_legacyUserKey);
  }
}
