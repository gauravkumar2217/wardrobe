import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/avatar.dart';
import 'user_service.dart';
import 'image_processing_service.dart';
import '../config/api_config.dart';
import 'laravel_auth_service.dart';

/// Service for 2D avatar generation from a single full-body photo
class Avatar2DService {
  static Map<String, dynamic> _extractData(Map<String, dynamic> decoded) {
    if (decoded['success'] == true && decoded['data'] is Map<String, dynamic>) {
      return decoded['data'] as Map<String, dynamic>;
    }
    throw Exception(decoded['message']?.toString() ?? 'Avatar request failed');
  }

  static Future<String> _pollUntilCompleted(String avatarId) async {
    if (kDebugMode) {
      debugPrint('⏳ Polling avatar status for $avatarId...');
    }

    Map<String, dynamic> status = {};
    var attempts = 0;
    while (attempts < ApiConfig.maxPollingAttempts) {
      await Future.delayed(ApiConfig.pollingInterval);
      status = await _getAvatarStatus(avatarId);
      final s = status['generation_status']?.toString();
      if (s == 'completed') return avatarId;
      if (s == 'failed') {
        throw Exception(
          status['error_message']?.toString() ?? 'Avatar generation failed',
        );
      }
      attempts++;
    }
    throw Exception('Avatar generation timed out');
  }

  static Future<Map<String, dynamic>> _getAvatarStatus(String avatarId) async {
    final token = await LaravelAuthService.ensureToken();
    final res = await http.get(
      Uri.parse(ApiConfig.avatarStatus(avatarId)),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.requestTimeout);
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response: ${res.body}');
    }
    return _extractData(decoded);
  }

  static Future<Map<String, dynamic>> _getAvatarMe() async {
    final token = await LaravelAuthService.ensureToken();
    final res = await http.get(
      Uri.parse(ApiConfig.avatarMe),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.requestTimeout);
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response: ${res.body}');
    }
    return _extractData(decoded);
  }

  /// Generate 2D avatar from a single full-body photo
  /// 
  /// Process:
  /// 1. Send body image to Laravel `/avatar/generate` (multipart)
  /// 2. Poll `/avatar/status/{avatarId}` until completed
  /// 3. Fetch `/avatar/me` and return avatar data from Laravel
  static Future<Avatar> generateAvatar({
    required String userId,
    required File bodyImageFile,
    double? userHeightCm,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🎨 Starting 2D avatar generation for user: $userId');
      }

      // Step 1: Process image (client-side) then upload to Laravel
      if (kDebugMode) {
        debugPrint('📤 Uploading body image to Laravel...');
      }

      final processedImage =
          await ImageProcessingService.processImageForBodyScan(bodyImageFile);
      if (processedImage == null) {
        throw Exception('Failed to process body image');
      }

      final token = await LaravelAuthService.ensureToken();
      final req = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.avatarGenerate),
      );
      req.headers['Accept'] = 'application/json';
      req.headers['Authorization'] = 'Bearer $token';
      req.files.add(
        await http.MultipartFile.fromPath(
          'body_image',
          processedImage.path,
        ),
      );
      req.fields['user_height_cm'] = (userHeightCm ?? 170).toString();

      final streamed = await req.send().timeout(ApiConfig.requestTimeout);
      final responseBody = await streamed.stream.bytesToString();
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid response: $responseBody');
      }

      String avatarId;
      if (streamed.statusCode == 202 && decoded['success'] == true) {
        final data = decoded['data'] as Map<String, dynamic>;
        avatarId = data['avatar_id']?.toString() ?? '';
        if (avatarId.isEmpty) {
          throw Exception('Avatar generation started but avatar_id missing');
        }
        if (data['resumed'] == true && kDebugMode) {
          debugPrint('♻️ Resuming in-progress avatar generation: $avatarId');
        } else if (kDebugMode) {
          debugPrint('✅ Avatar generation started: $avatarId');
        }
      } else {
        throw Exception(
          decoded['message']?.toString() ??
              'Avatar request failed (${streamed.statusCode})',
        );
      }

      // Step 2: Poll status until completed
      await _pollUntilCompleted(avatarId);

      // Step 3: Fetch full avatar info
      final me = await _getAvatarMe();
      final avatar = Avatar.fromApiJson(me, userId).copyWith(
        generationStatus: 'completed',
        generationJobId: avatarId,
        userHeightCm: userHeightCm,
      );

      if (kDebugMode) {
        debugPrint('✅ Avatar generated: ${avatar.avatarImageUrl}');
      }

      return avatar;
    } catch (e) {
      debugPrint('❌ Error generating 2D avatar: $e');
      rethrow;
    }
  }

  /// Get avatar for user
  static Future<Avatar?> getAvatar(String userId) async {
    try {
      return await UserService.getAvatar(userId);
    } catch (e) {
      debugPrint('Error getting avatar: $e');
      return null;
    }
  }

  /// Get cached pose landmarks for user
  static Future<Map<String, dynamic>?> getPoseLandmarks(String userId) async {
    try {
      final avatar = await getAvatar(userId);
      return avatar?.poseLandmarks;
    } catch (e) {
      debugPrint('Error getting pose landmarks: $e');
      return null;
    }
  }
}
