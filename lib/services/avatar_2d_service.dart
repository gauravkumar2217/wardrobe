import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/avatar.dart';
import 'image_processing_service.dart';
import 'laravel_auth_service.dart';
import 'user_service.dart';

/// Result of starting avatar generation (non-blocking).
class AvatarGenerationStartResult {
  final String avatarId;
  final String generationStatus;
  final bool resumed;
  final String message;

  const AvatarGenerationStartResult({
    required this.avatarId,
    required this.generationStatus,
    this.resumed = false,
    required this.message,
  });
}

/// Service for 2D avatar generation from a single full-body photo.
///
/// Creation is async on Laravel: start returns immediately, then poll / FCM
/// notifies when completed or failed.
class Avatar2DService {
  static const String _pendingAvatarIdKey = 'pending_avatar_id';
  static const String _pendingAvatarUserKey = 'pending_avatar_user_id';

  static Timer? _backgroundPollTimer;
  static String? _pollingAvatarId;
  static final List<void Function(Avatar)> _statusListeners = [];

  static Map<String, dynamic> _extractData(Map<String, dynamic> decoded) {
    if (decoded['success'] == true && decoded['data'] is Map<String, dynamic>) {
      return decoded['data'] as Map<String, dynamic>;
    }
    throw Exception(decoded['message']?.toString() ?? 'Avatar request failed');
  }

  /// Listen for status updates from background polling / FCM refresh.
  static void addStatusListener(void Function(Avatar) listener) {
    _statusListeners.add(listener);
  }

  static void removeStatusListener(void Function(Avatar) listener) {
    _statusListeners.remove(listener);
  }

  static void _emitStatus(Avatar avatar) {
    for (final listener in List.of(_statusListeners)) {
      try {
        listener(avatar);
      } catch (e) {
        debugPrint('Avatar status listener error: $e');
      }
    }
  }

  /// Used by FCM / local notification handlers to refresh UI listeners.
  static void notifyExternalStatus(Avatar avatar) {
    _emitStatus(avatar);
  }

  static Future<void> savePendingAvatarId({
    required String userId,
    required String avatarId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingAvatarIdKey, avatarId);
    await prefs.setString(_pendingAvatarUserKey, userId);
  }

  static Future<String?> getPendingAvatarId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final storedUser = prefs.getString(_pendingAvatarUserKey);
    if (storedUser != userId) return null;
    return prefs.getString(_pendingAvatarIdKey);
  }

  static Future<void> clearPendingAvatarId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingAvatarIdKey);
    await prefs.remove(_pendingAvatarUserKey);
  }

  static Future<Map<String, dynamic>> getAvatarStatus(String avatarId) async {
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

  /// Start avatar generation and return immediately (does not wait for AI).
  static Future<AvatarGenerationStartResult> startAvatarGeneration({
    required String userId,
    required File bodyImageFile,
    double? userHeightCm,
  }) async {
    if (kDebugMode) {
      debugPrint('🎨 Starting 2D avatar generation for user: $userId');
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

    if (streamed.statusCode != 202 || decoded['success'] != true) {
      throw Exception(
        decoded['message']?.toString() ??
            'Avatar request failed (${streamed.statusCode})',
      );
    }

    final data = decoded['data'] as Map<String, dynamic>;
    final avatarId = data['avatar_id']?.toString() ?? '';
    if (avatarId.isEmpty) {
      throw Exception('Avatar generation started but avatar_id missing');
    }

    final status = data['generation_status']?.toString() ?? 'pending';
    final resumed = data['resumed'] == true;
    final message = data['message']?.toString() ??
        decoded['message']?.toString() ??
        'Avatar is being created. We will notify you when it is ready.';

    await savePendingAvatarId(userId: userId, avatarId: avatarId);
    startBackgroundPolling(userId: userId, avatarId: avatarId);

    if (kDebugMode) {
      debugPrint(
        resumed
            ? '♻️ Resuming avatar generation: $avatarId'
            : '✅ Avatar generation started: $avatarId',
      );
    }

    return AvatarGenerationStartResult(
      avatarId: avatarId,
      generationStatus: status,
      resumed: resumed,
      message: message,
    );
  }

  /// Retry a failed avatar using the server-stored body image.
  static Future<AvatarGenerationStartResult> retryAvatarGeneration({
    required String userId,
    required String avatarId,
  }) async {
    final token = await LaravelAuthService.ensureToken();
    final res = await http.post(
      Uri.parse(ApiConfig.avatarRetry(avatarId)),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.requestTimeout);

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response: ${res.body}');
    }

    if ((res.statusCode != 202 && res.statusCode != 200) ||
        decoded['success'] != true) {
      throw Exception(
        decoded['message']?.toString() ??
            'Avatar retry failed (${res.statusCode})',
      );
    }

    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    final newId = data['avatar_id']?.toString() ?? avatarId;
    final status = data['generation_status']?.toString() ?? 'pending';
    final message = data['message']?.toString() ??
        'Avatar creation restarted. We will notify you when it is ready.';

    if (status == 'completed') {
      await clearPendingAvatarId();
      stopBackgroundPolling();
    } else {
      await savePendingAvatarId(userId: userId, avatarId: newId);
      startBackgroundPolling(userId: userId, avatarId: newId);
    }

    return AvatarGenerationStartResult(
      avatarId: newId,
      generationStatus: status,
      resumed: data['resumed'] == true,
      message: message,
    );
  }

  /// Poll once and return the latest avatar snapshot for [userId].
  static Future<Avatar?> refreshAvatar(String userId) async {
    try {
      return await getAvatar(userId);
    } catch (e) {
      debugPrint('Error refreshing avatar: $e');
      return null;
    }
  }

  /// Start lightweight background polling while the app is open.
  static void startBackgroundPolling({
    required String userId,
    required String avatarId,
  }) {
    if (_pollingAvatarId == avatarId && _backgroundPollTimer != null) {
      return;
    }
    stopBackgroundPolling();
    _pollingAvatarId = avatarId;

    var attempts = 0;
    _backgroundPollTimer = Timer.periodic(ApiConfig.pollingInterval, (timer) async {
      attempts++;
      if (attempts > ApiConfig.maxPollingAttempts) {
        stopBackgroundPolling();
        return;
      }

      try {
        final status = await getAvatarStatus(avatarId);
        final s = status['generation_status']?.toString();

        if (s == 'completed' || s == 'failed') {
          stopBackgroundPolling();
          await clearPendingAvatarId();

          final me = await _getAvatarMe();
          final avatar = Avatar.fromApiJson(me, userId).copyWith(
            generationStatus: s,
            generationJobId: avatarId,
            errorMessage: status['error_message']?.toString(),
          );
          _emitStatus(avatar);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Avatar background poll error: $e');
        }
      }
    });
  }

  static void stopBackgroundPolling() {
    _backgroundPollTimer?.cancel();
    _backgroundPollTimer = null;
    _pollingAvatarId = null;
  }

  /// Resume polling for any pending avatar after app start / login.
  static Future<void> resumePendingPolling(String userId) async {
    final pendingId = await getPendingAvatarId(userId);
    if (pendingId == null || pendingId.isEmpty) return;

    try {
      final status = await getAvatarStatus(pendingId);
      final s = status['generation_status']?.toString();
      if (s == 'pending' || s == 'processing') {
        startBackgroundPolling(userId: userId, avatarId: pendingId);
        return;
      }
      await clearPendingAvatarId();
      final me = await _getAvatarMe();
      _emitStatus(
        Avatar.fromApiJson(me, userId).copyWith(
          generationStatus: s,
          generationJobId: pendingId,
          errorMessage: status['error_message']?.toString(),
        ),
      );
    } catch (e) {
      debugPrint('Failed to resume avatar polling: $e');
    }
  }

  /// Legacy blocking helper (kept for any callers that still await completion).
  static Future<Avatar> generateAvatar({
    required String userId,
    required File bodyImageFile,
    double? userHeightCm,
  }) async {
    final started = await startAvatarGeneration(
      userId: userId,
      bodyImageFile: bodyImageFile,
      userHeightCm: userHeightCm,
    );

    var attempts = 0;
    while (attempts < ApiConfig.maxPollingAttempts) {
      await Future.delayed(ApiConfig.pollingInterval);
      final status = await getAvatarStatus(started.avatarId);
      final s = status['generation_status']?.toString();
      if (s == 'completed') {
        await clearPendingAvatarId();
        final me = await _getAvatarMe();
        return Avatar.fromApiJson(me, userId).copyWith(
          generationStatus: 'completed',
          generationJobId: started.avatarId,
          userHeightCm: userHeightCm,
        );
      }
      if (s == 'failed') {
        await clearPendingAvatarId();
        throw Exception(
          status['error_message']?.toString() ?? 'Avatar generation failed',
        );
      }
      attempts++;
    }
    throw Exception('Avatar generation timed out');
  }

  static Future<Avatar?> getAvatar(String userId) async {
    try {
      return await UserService.getAvatar(userId);
    } catch (e) {
      debugPrint('Error getting avatar: $e');
      return null;
    }
  }

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
