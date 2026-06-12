import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/detected_cloth_item.dart';
import 'laravel_auth_service.dart';

/// Gemini-powered multi-item clothing detection via Laravel API.
class ClothDetectionService {
  static Future<Map<String, dynamic>> _extractData(Map<String, dynamic> decoded) {
    if (decoded['success'] == true) {
      return Future.value(decoded['data'] as Map<String, dynamic>? ?? {});
    }
    throw Exception(decoded['message']?.toString() ?? 'Request failed');
  }

  static Future<({String sessionId, List<DetectedClothItem> items})> detectItems(
    File imageFile,
  ) async {
    final token = await LaravelAuthService.ensureToken();
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/clothes/detect'),
    );
    req.headers['Accept'] = 'application/json';
    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    final streamed = await req.send().timeout(ApiConfig.requestTimeout);
    final body = await streamed.stream.bytesToString();
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid detection response');
    }

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception(
        decoded['message']?.toString() ?? 'Detection failed (${streamed.statusCode})',
      );
    }

    final data = await _extractData(decoded);
    final sessionId = data['session_id']?.toString() ?? '';
    final rawItems = data['items'] as List? ?? [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(DetectedClothItem.fromJson)
        .where((i) => i.id.isNotEmpty)
        .toList();

    if (sessionId.isEmpty || items.isEmpty) {
      throw Exception('No clothing items detected');
    }

    if (kDebugMode) {
      debugPrint('Detected ${items.length} items (session: $sessionId)');
    }

    return (sessionId: sessionId, items: items);
  }

  static Future<List<DetectedClothItem>> extractItems({
    required String sessionId,
    required List<String> itemIds,
  }) async {
    final token = await LaravelAuthService.ensureToken();
    final res = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/clothes/extract'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'session_id': sessionId,
            'item_ids': itemIds,
          }),
        )
        .timeout(const Duration(minutes: 3));

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid extraction response');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        decoded['message']?.toString() ?? 'Extraction failed (${res.statusCode})',
      );
    }

    final data = await _extractData(decoded);
    final rawItems = data['items'] as List? ?? [];
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(DetectedClothItem.fromJson)
        .toList();
  }

  static Future<String> uploadClothImage(File imageFile) async {
    final token = await LaravelAuthService.ensureToken();
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/clothes/upload'),
    );
    req.headers['Accept'] = 'application/json';
    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    final streamed = await req.send().timeout(ApiConfig.requestTimeout);
    final body = await streamed.stream.bytesToString();
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid upload response');
    }

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception(
        decoded['message']?.toString() ?? 'Upload failed (${streamed.statusCode})',
      );
    }

    final data = await _extractData(decoded);
    final url = data['image_url']?.toString() ?? '';
    if (url.isEmpty) throw Exception('Upload succeeded but image URL missing');
    return url;
  }
}
