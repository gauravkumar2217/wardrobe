import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../config/api_config.dart';
import '../models/avatar_advanced.dart';

/// Service for AI avatar generation via Laravel API
class AvatarGenerationService {
  /// Upload 6 images and request avatar generation
  static Future<AvatarAdvanced> generateAvatar({
    required String userId,
    required Map<String, File>
        faceImages, // {'left': File, 'center': File, 'right': File}
    required Map<String, File>
        bodyImages, // {'left': File, 'center': File, 'right': File}
    required double userHeightCm,
    String? firebaseAuthToken,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🎨 Starting avatar generation for user: $userId');
      }

      // Step 1: Upload all 6 images to your Laravel backend or storage
      // NOTE: This placeholder assumes the Flutter app only passes local files
      // and the Laravel backend will handle uploads. Implement as needed.
      //
      // For now, we pass empty URLs; the backend should fetch images itself
      // or you can extend this to upload to Firebase/your storage first.
      final faceLeftUrl = '';
      final faceCenterUrl = '';
      final faceRightUrl = '';
      final bodyLeftUrl = '';
      final bodyCenterUrl = '';
      final bodyRightUrl = '';

      // Step 2: Create initial avatar record with pending status
      final initialAvatar = AvatarAdvanced(
        userId: userId,
        faceImageLeftUrl: faceLeftUrl,
        faceImageCenterUrl: faceCenterUrl,
        faceImageRightUrl: faceRightUrl,
        bodyImageLeftUrl: bodyLeftUrl,
        bodyImageCenterUrl: bodyCenterUrl,
        bodyImageRightUrl: bodyRightUrl,
        userHeightCm: userHeightCm,
        generationStatus: AvatarGenerationStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save initial state to Firestore
      await _saveAvatarAdvanced(initialAvatar);

      // Step 3: Call Laravel API to start generation
      final jobId = await _requestAvatarGeneration(
        userId: userId,
        faceLeftUrl: faceLeftUrl,
        faceCenterUrl: faceCenterUrl,
        faceRightUrl: faceRightUrl,
        bodyLeftUrl: bodyLeftUrl,
        bodyCenterUrl: bodyCenterUrl,
        bodyRightUrl: bodyRightUrl,
        userHeightCm: userHeightCm,
        firebaseAuthToken: firebaseAuthToken,
      );

      // Step 4: Update avatar with job ID and processing status
      final processingAvatar = initialAvatar.copyWith(
        generationStatus: AvatarGenerationStatus.processing,
        generationJobId: jobId,
        updatedAt: DateTime.now(),
      );
      await _saveAvatarAdvanced(processingAvatar);

      if (kDebugMode) {
        debugPrint('✅ Avatar generation job started: $jobId');
      }

      return processingAvatar;
    } catch (e) {
      debugPrint('❌ Error generating avatar: $e');
      rethrow;
    }
  }

  /// Request avatar generation from Laravel API
  static Future<String> _requestAvatarGeneration({
    required String userId,
    required String faceLeftUrl,
    required String faceCenterUrl,
    required String faceRightUrl,
    required String bodyLeftUrl,
    required String bodyCenterUrl,
    required String bodyRightUrl,
    required double userHeightCm,
    String? firebaseAuthToken,
  }) async {
    try {
      final url = Uri.parse(ApiConfig.avatarGenerate);

      final requestBody = {
        'userId': userId,
        'faceImages': {
          'left': faceLeftUrl,
          'center': faceCenterUrl,
          'right': faceRightUrl,
        },
        'bodyImages': {
          'left': bodyLeftUrl,
          'center': bodyCenterUrl,
          'right': bodyRightUrl,
        },
        'userHeightCm': userHeightCm,
      };

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // Add API key if available
      if (ApiConfig.apiKey != null) {
        headers['X-API-Key'] = ApiConfig.apiKey!;
      }

      // Add Firebase Auth token if provided
      if (firebaseAuthToken != null) {
        headers['Authorization'] = 'Bearer $firebaseAuthToken';
      }

      final response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 202) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['jobId'] as String;
      } else {
        throw Exception(
          'Avatar generation request failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error requesting avatar generation: $e');
      rethrow;
    }
  }

  /// Poll for avatar generation status
  static Future<AvatarAdvanced?> pollGenerationStatus({
    required String userId,
    required String jobId,
    int maxAttempts = ApiConfig.maxPollingAttempts,
  }) async {
    try {
      int attempts = 0;

      while (attempts < maxAttempts) {
        await Future.delayed(ApiConfig.pollingInterval);

        final status = await _getJobStatus(jobId);

        if (status == null) {
          attempts++;
          continue;
        }

        final statusValue = status['status'] as String;

        if (statusValue == 'completed') {
          // Generation completed, fetch updated avatar
          final avatar = await getAvatar(userId);
          return avatar;
        } else if (statusValue == 'failed') {
          // Generation failed
          final error = status['error'] as String? ?? 'Unknown error';
          final avatar = await getAvatar(userId);
          if (avatar != null) {
            return avatar.copyWith(
              generationStatus: AvatarGenerationStatus.failed,
              generationError: error,
              updatedAt: DateTime.now(),
            );
          }
          return null;
        }

        // Still processing
        attempts++;
      }

      // Timeout
      throw Exception(
          'Avatar generation timed out after ${maxAttempts * ApiConfig.pollingInterval.inSeconds} seconds');
    } catch (e) {
      debugPrint('Error polling generation status: $e');
      rethrow;
    }
  }

  /// Get job status from Laravel API
  static Future<Map<String, dynamic>?> _getJobStatus(String jobId) async {
    try {
      final url = Uri.parse(ApiConfig.jobStatus(jobId));

      final headers = {
        'Accept': 'application/json',
      };

      if (ApiConfig.apiKey != null) {
        headers['X-API-Key'] = ApiConfig.apiKey!;
      }

      final response = await http
          .get(url, headers: headers)
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Error getting job status: $e');
      return null;
    }
  }

  /// Get avatar from Firestore
  static Future<AvatarAdvanced?> getAvatar(String userId) async {
    try {
      // Try to get from Firestore first
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('avatar')
          .doc('current')
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return AvatarAdvanced.fromJson(doc.data()!, userId);
    } catch (e) {
      debugPrint('Error getting avatar: $e');
      return null;
    }
  }

  /// Save avatar to Firestore
  static Future<void> _saveAvatarAdvanced(AvatarAdvanced avatar) async {
    try {
      final avatarData = avatar.toJson();
      avatarData['updatedAt'] = FieldValue.serverTimestamp();

      if (!avatarData.containsKey('createdAt')) {
        avatarData['createdAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(avatar.userId)
          .collection('avatar')
          .doc('current')
          .set(avatarData);

      if (kDebugMode) {
        debugPrint('✅ Avatar saved to Firestore');
      }
    } catch (e) {
      debugPrint('Error saving avatar: $e');
      rethrow;
    }
  }

  /// Regenerate avatar (call Laravel API)
  static Future<String> regenerateAvatar({
    required String userId,
    String? firebaseAuthToken,
  }) async {
    try {
      final url = Uri.parse(ApiConfig.avatarRegenerate(userId));

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (ApiConfig.apiKey != null) {
        headers['X-API-Key'] = ApiConfig.apiKey!;
      }

      if (firebaseAuthToken != null) {
        headers['Authorization'] = 'Bearer $firebaseAuthToken';
      }

      final response = await http
          .put(url, headers: headers)
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 202) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['jobId'] as String;
      } else {
        throw Exception(
          'Avatar regeneration failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error regenerating avatar: $e');
      rethrow;
    }
  }
}
