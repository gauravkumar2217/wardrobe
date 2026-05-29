import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'laravel_auth_service.dart';

class LaravelApiClient {
  static Future<Map<String, dynamic>> getJson(String url) async {
    final token = await LaravelAuthService.ensureToken();
    final res = await http.get(
      Uri.parse(url),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.requestTimeout);

    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected response: ${res.body}');
    }
    throw Exception('Request failed (${res.statusCode}): ${res.body}');
  }

  static Future<Map<String, dynamic>> postJson(
    String url,
    Map<String, dynamic> payload,
  ) async {
    final token = await LaravelAuthService.ensureToken();
    final res = await http
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.requestTimeout);

    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected response: ${res.body}');
    }
    throw Exception('Request failed (${res.statusCode}): ${res.body}');
  }
}

