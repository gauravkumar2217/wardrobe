import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/cloth.dart';
import '../config/api_config.dart';
import '../utils/try_on_category.dart';
import 'laravel_auth_service.dart';

/// Service for 2D virtual try-on
class TryOn2DService {
  static Future<Map<String, dynamic>> _postLaravel(
    Map<String, dynamic> payload,
  ) async {
    final token = await LaravelAuthService.ensureToken();
    final url = Uri.parse(ApiConfig.tryOnRender);
    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.requestTimeout);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response: ${response.body}');
    }
    if (decoded['success'] != true) {
      throw Exception(decoded['message']?.toString() ?? 'Try-on failed');
    }
    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  static Future<String> _pollResultUrl(String resultId) async {
    final token = await LaravelAuthService.ensureToken();
    final url = Uri.parse(ApiConfig.tryOnStatus(resultId));
    var attempts = 0;
    while (attempts < ApiConfig.maxPollingAttempts) {
      await Future.delayed(ApiConfig.pollingInterval);
      final res = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(ApiConfig.requestTimeout);

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        attempts++;
        continue;
      }
      if (decoded['success'] != true) {
        throw Exception(decoded['message']?.toString() ?? 'Try-on failed');
      }
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        final status = data['status']?.toString();
        if (status == 'completed') {
          final resultUrl = data['result_url']?.toString();
          if (resultUrl != null && resultUrl.isNotEmpty) return resultUrl;
          throw Exception('Try-on completed but result_url missing');
        }
        if (status == 'failed') {
          throw Exception(data['error_message']?.toString() ?? 'Try-on failed');
        }
      }
      attempts++;
    }
    throw Exception('Try-on timed out');
  }

  /// Create try-on result by overlaying clothing on avatar
  /// 
  /// Process:
  /// 1. Call Cloud Function with avatar and clothing info
  /// 2. Return try-on result URL
  static Future<String> createTryOn({
    required String userId,
    required String avatarUrl,
    required String clothingItemId,
    required String clothingImageUrl,
    String? clothingType,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('👔 Creating try-on for user: $userId, clothing: $clothingItemId');
      }

      final data = await _postLaravel({
        'clothing_item_id': clothingItemId,
        'clothing_type': clothingType != null
            ? TryOnCategory.slotForType(clothingType)
            : null,
        if (clothingType != null) 'display_type': clothingType,
      });

      final status = data['status']?.toString();
      final resultId = data['result_id']?.toString();
      if (status == 'completed') {
        final url = data['result_url']?.toString();
        if (url != null && url.isNotEmpty) return url;
      }
      if (resultId == null || resultId.isEmpty) {
        throw Exception('Try-on started but result_id missing');
      }
      final resultUrl = await _pollResultUrl(resultId);

      if (kDebugMode) {
        debugPrint('✅ Try-on created: $resultUrl');
      }

      return resultUrl;
    } catch (e) {
      debugPrint('❌ Error creating try-on: $e');
      rethrow;
    }
  }

  /// Get try-on result by result ID (Laravel API).
  static Future<Map<String, dynamic>?> getTryOnResult(String resultId) async {
    try {
      final token = await LaravelAuthService.ensureToken();
      final url = Uri.parse(ApiConfig.tryOnStatus(resultId));
      final res = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(ApiConfig.requestTimeout);
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
        return null;
      }
      final data = decoded['data'];
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (e) {
      debugPrint('Error getting try-on result: $e');
      return null;
    }
  }

  /// Get recent try-on results for a user (not persisted client-side yet).
  static Future<List<Map<String, dynamic>>> getUserTryOnResults(
    String userId,
  ) async {
    return [];
  }

  /// Best image URL for try-on (cutout helps Gemini fit the garment).
  static String clothingImageUrlForTryOn(Cloth cloth) {
    if (cloth.processedImageUrl != null &&
        cloth.processedImageUrl!.trim().isNotEmpty) {
      return cloth.processedImageUrl!;
    }
    return cloth.imageUrl;
  }

  /// Create try-on from Cloth model
  static Future<String> createTryOnFromCloth({
    required String userId,
    required String avatarUrl,
    required Cloth cloth,
  }) async {
    return createTryOn(
      userId: userId,
      avatarUrl: avatarUrl,
      clothingItemId: cloth.id,
      clothingImageUrl: clothingImageUrlForTryOn(cloth),
      clothingType: cloth.clothType,
    );
  }

  /// Full outfit: one item per category (shirt, pants, shoes, accessory).
  /// Backend dedupes by category; same slot replaces previous.
  static Future<String> createTryOnForOutfit({
    required String userId,
    required String avatarUrl,
    required List<Cloth> garments,
  }) async {
    if (garments.isEmpty) {
      throw Exception('At least one garment is required');
    }
    if (kDebugMode) {
      debugPrint(
        '👔 Creating multi try-on: ${garments.length} piece(s)',
      );
    }

    final data = await _postLaravel({
      'garments': garments
          .map(
            (c) => {
              'clothing_item_id': c.id,
              'clothing_type': TryOnCategory.slotForCloth(c),
              'display_type': c.clothType,
            },
          )
          .toList(),
    });

    final status = data['status']?.toString();
    final resultId = data['result_id']?.toString();
    if (status == 'completed') {
      final url = data['result_url']?.toString();
      if (url != null && url.isNotEmpty) return url;
    }
    if (resultId == null || resultId.isEmpty) {
      throw Exception('Try-on started but result_id missing');
    }
    final resultUrl = await _pollResultUrl(resultId);

    if (kDebugMode) {
      debugPrint('✅ Try-on outfit created: $resultUrl');
    }

    return resultUrl;
  }
}
