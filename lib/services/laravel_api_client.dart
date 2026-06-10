import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'laravel_auth_service.dart';

class LaravelApiClient {
  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, String> _authHeaders(String token) => {
        ..._jsonHeaders,
        'Authorization': 'Bearer $token',
      };

  static Future<Map<String, dynamic>> getJson(String url) async {
    return _requestWithAuth(
      (token) => http.get(Uri.parse(url), headers: _authHeaders(token)),
    );
  }

  static Future<Map<String, dynamic>> getPublicJson(String url) async {
    final res = await http
        .get(Uri.parse(url), headers: {'Accept': 'application/json'})
        .timeout(ApiConfig.requestTimeout);
    return _decodeResponse(res);
  }

  static Future<Map<String, dynamic>> postJson(
    String url,
    Map<String, dynamic> payload,
  ) async {
    return _requestWithAuth(
      (token) => http.post(
        Uri.parse(url),
        headers: _authHeaders(token),
        body: jsonEncode(payload),
      ),
    );
  }

  static Future<Map<String, dynamic>> putJson(
    String url,
    Map<String, dynamic> payload,
  ) async {
    return _requestWithAuth(
      (token) => http.put(
        Uri.parse(url),
        headers: _authHeaders(token),
        body: jsonEncode(payload),
      ),
    );
  }

  static Future<Map<String, dynamic>> deleteJson(String url) async {
    return _requestWithAuth(
      (token) => http.delete(Uri.parse(url), headers: _authHeaders(token)),
    );
  }

  static dynamic extractData(Map<String, dynamic> body) {
    if (body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'Request failed');
    }
    return body['data'];
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

    return _decodeResponse(res);
  }

  static Map<String, dynamic> _decodeResponse(http.Response res) {
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected response: ${res.body}');
    }
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message']?.toString() ?? 'Request failed';
      throw Exception('$message (${res.statusCode})');
    }
    throw Exception('Request failed (${res.statusCode}): ${res.body}');
  }
}
