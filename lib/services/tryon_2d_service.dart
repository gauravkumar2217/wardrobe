import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import '../models/cloth.dart';

/// Service for 2D virtual try-on
class TryOn2DService {
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

      final data = await _callFunctionHttp('createTryOn', {
        'userId': userId,
        'avatarUrl': avatarUrl,
        'clothingItemId': clothingItemId,
        'clothingImageUrl': clothingImageUrl,
        if (clothingType != null) 'clothingType': clothingType,
      });
      final resultUrl = data['resultUrl'] as String;

      if (kDebugMode) {
        debugPrint('✅ Try-on created: $resultUrl');
      }

      return resultUrl;
    } catch (e) {
      debugPrint('❌ Error creating try-on: $e');
      rethrow;
    }
  }

  /// Get try-on result by result ID
  static Future<Map<String, dynamic>?> getTryOnResult(String resultId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('tryon_results')
          .doc(resultId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return doc.data();
    } catch (e) {
      debugPrint('Error getting try-on result: $e');
      return null;
    }
  }

  /// Get all try-on results for a user
  static Future<List<Map<String, dynamic>>> getUserTryOnResults(
    String userId,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('tryon_results')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting user try-on results: $e');
      return [];
    }
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
      clothingImageUrl: cloth.imageUrl,
      clothingType: cloth.clothType,
    );
  }
}
