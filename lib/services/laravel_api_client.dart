import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'laravel_auth_service.dart';

class LaravelApiClient {
  static Future<Map<String, dynamic>> getJson(String url) async {
    return _requestWithAuth(
      (token) => http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );
  }

  static Future<Map<String, dynamic>> postJson(
    String url,
    Map<String, dynamic> payload,
  ) async {
    return _requestWithAuth(
      (token) => http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ),
    );
  }

  static Future<Map<String, dynamic>> _requestWithAuth(
    Future<http.Response> Function(String token) send,
  ) async {
    var token = await LaravelAuthService.ensureToken();
    var res = await send(token).timeout(ApiConfig.requestTimeout);

    if (res.statusCode == 401) {
      await LaravelAuthService.clearToken();
      token = await LaravelAuthService.ensureToken(forceRefresh: true);
      res = await send(token).timeout(ApiConfig.requestTimeout);
    }

    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected response: ${res.body}');
    }
    throw Exception('Request failed (${res.statusCode}): ${res.body}');
  }
}

