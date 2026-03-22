import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import '../models/avatar.dart';
import 'storage_service.dart';
import 'user_service.dart';
import 'image_processing_service.dart';

/// Service for 2D avatar generation from a single full-body photo
class Avatar2DService {
  static Future<Map<String, dynamic>> _callFunctionHttp(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User is not authenticated');
    }

    final idToken = await currentUser.getIdToken();
    final projectId = Firebase.app().options.projectId;
    final url = Uri.parse(
      'https://us-central1-$projectId.cloudfunctions.net/$functionName',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'data': payload}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Function $functionName failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['error'] != null) {
      throw Exception('Function $functionName error: ${decoded['error']}');
    }

    final result = decoded['result'];
    if (result is Map<String, dynamic>) return result;
    throw Exception('Unexpected function response for $functionName');
  }

  /// Generate 2D avatar from a single full-body photo
  /// 
  /// Process:
  /// 1. Upload body image to Firebase Storage
  /// 2. Call Cloud Function to generate avatar
  /// 3. Save avatar data to Firestore
  static Future<Avatar> generateAvatar({
    required String userId,
    required File bodyImageFile,
    double? userHeightCm,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🎨 Starting 2D avatar generation for user: $userId');
      }

      // Step 1: Process and upload body image
      if (kDebugMode) {
        debugPrint('📤 Uploading body image to Firebase Storage...');
      }

      final processedImage =
          await ImageProcessingService.processImageForBodyScan(bodyImageFile);
      if (processedImage == null) {
        throw Exception('Failed to process body image');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'body_$timestamp.jpg';
      // Keep upload path aligned with storage.rules:
      // match /users/{userId}/avatar/{imageType}/{imageName}
      final ref = StorageService.getStorageRef()
          .child('users/$userId/avatar/body/$fileName');
      final metadata = StorageService.getMetadata(contentType: 'image/jpeg');

      await ref.putFile(processedImage, metadata);
      final bodyImageUrl = await ref.getDownloadURL();

      if (kDebugMode) {
        debugPrint('✅ Body image uploaded: $bodyImageUrl');
      }

      // Step 2: Call Cloud Function to generate avatar
      if (kDebugMode) {
        debugPrint('☁️ Calling Cloud Function: generateAvatar...');
      }

      final data = await _callFunctionHttp('generateAvatar', {
        'userId': userId,
        'bodyImageUrl': bodyImageUrl,
        if (userHeightCm != null) 'userHeightCm': userHeightCm,
      });
      final avatarUrl = data['avatarUrl'] as String;
      final poseLandmarks = data['poseLandmarks'] as Map<String, dynamic>?;
      final measurements = data['measurements'] as Map<String, dynamic>?;

      if (kDebugMode) {
        debugPrint('✅ Avatar generated: $avatarUrl');
      }

      // Step 3: Create avatar model
      final bodyMeasurements = measurements != null
          ? BodyMeasurements(
              shoulderWidthCm: (measurements['shoulderWidthCm'] as num?)?.toDouble(),
              hipWidthCm: (measurements['hipWidthCm'] as num?)?.toDouble(),
              heightCm: (measurements['heightCm'] as num?)?.toDouble(),
            )
          : null;

      final avatar = Avatar(
        userId: userId,
        bodyImageUrl: bodyImageUrl,
        avatarImageUrl: avatarUrl,
        poseLandmarks: poseLandmarks,
        userHeightCm: userHeightCm ?? bodyMeasurements?.heightCm,
        measurements: bodyMeasurements,
        generationStatus: 'completed',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Step 4: Save to Firestore
      await UserService.saveAvatar(avatar);

      if (kDebugMode) {
        debugPrint('✅ Avatar saved to Firestore');
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
