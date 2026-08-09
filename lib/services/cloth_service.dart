import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/cloth.dart';
import 'laravel_api_client.dart';
import 'cloth_detection_service.dart';
import 'storage_service.dart';
import 'push_notification_service.dart';
import 'content_filter_service.dart';
import 'background_removal_service.dart';

/// Cloth service for managing clothes
class ClothService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get Firestore path for clothes
  static String _clothesPath(String userId, String wardrobeId) {
    return 'users/$userId/wardrobes/$wardrobeId/clothes';
  }

  static String _normalizeSeason(String season) {
    final s = season.trim().toLowerCase();
    const map = {
      'spring': 'spring',
      'summer': 'summer',
      'fall': 'fall',
      'autumn': 'fall',
      'winter': 'winter',
      'all': 'all',
      'all season': 'all',
    };
    return map[s] ?? 'all';
  }

  static Map<String, dynamic> _colorTagsPayload(ColorTags colorTags) => {
        'primary': colorTags.primary,
        if (colorTags.secondary != null) 'secondary': colorTags.secondary,
        'colors': colorTags.colors,
        'is_multi_color': colorTags.isMultiColor,
      };

  static Map<String, dynamic>? _placementPayload(PlacementDetails? details) {
    if (details == null) return null;
    return {
      'shop_name': details.shopName,
      'given_date': details.givenDate.toIso8601String(),
      'return_date': details.returnDate.toIso8601String(),
    };
  }

  /// Add cloth to wardrobe via Laravel API.
  static Future<String> addCloth({
    required String userId,
    required String wardrobeId,
    required File imageFile,
    required String season,
    required String placement,
    PlacementDetails? placementDetails,
    required ColorTags colorTags,
    required String clothType,
    required String category,
    required List<String> occasions,
    String visibility = 'private',
    String itemKind = 'cloth',
    AiDetected? aiDetected,
    String? imageUrl,
    String? processedImageUrl,
    bool hasProcessedImage = false,
  }) async {
    try {
      if (occasions.isEmpty) {
        throw Exception('At least one occasion must be selected');
      }

      final resolvedImageUrl = imageUrl ??
          await ClothDetectionService.uploadClothImage(imageFile);

      String? resolvedProcessed = processedImageUrl;
      var resolvedHasProcessed = hasProcessedImage;

      if (!resolvedHasProcessed) {
        try {
          final processedImage =
              await BackgroundRemovalService.removeBackgroundAuto(imageFile);
          if (processedImage != null) {
            resolvedProcessed =
                await ClothDetectionService.uploadClothImage(processedImage);
            resolvedHasProcessed = true;
          }
        } catch (e) {
          debugPrint('Background removal failed (non-critical): $e');
        }
      }

      final payload = <String, dynamic>{
        'wardrobe_id': wardrobeId,
        'image_url': resolvedImageUrl,
        if (resolvedProcessed != null) 'processed_image_url': resolvedProcessed,
        'has_processed_image': resolvedHasProcessed,
        'season': _normalizeSeason(season),
        'placement': placement,
        if (_placementPayload(placementDetails) != null)
          'placement_details': _placementPayload(placementDetails),
        'color_tags': _colorTagsPayload(colorTags),
        'cloth_type': clothType,
        'category': category,
        'occasions': occasions,
        'visibility': visibility,
        if (aiDetected != null)
          'ai_detected': {
            'cloth_type': aiDetected.clothType,
            'colors': aiDetected.colors,
            'confidence': aiDetected.confidence,
            'detected_at': aiDetected.detectedAt.toIso8601String(),
            'item_kind': itemKind,
          },
      };

      final body = await LaravelApiClient.postJson(ApiConfig.clothes, payload);
      final data = LaravelApiClient.extractData(body);
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid cloth create response');
      }
      final clothId = data['id']?.toString() ?? '';
      if (clothId.isEmpty) throw Exception('Cloth created but id missing');

      if (kDebugMode) debugPrint('Cloth added via Laravel: $clothId');
      return clothId;
    } catch (e) {
      debugPrint('Failed to add cloth: $e');
      rethrow;
    }
  }

  /// Create cloth when image URLs are already uploaded (batch AI flow).
  static Future<String> createClothFromUrls({
    required String wardrobeId,
    required String imageUrl,
    String? processedImageUrl,
    bool hasProcessedImage = false,
    required String season,
    required String placement,
    required ColorTags colorTags,
    required String clothType,
    required String category,
    required List<String> occasions,
    String visibility = 'private',
    String itemKind = 'cloth',
    Map<String, dynamic>? aiDetected,
  }) async {
    final payload = <String, dynamic>{
      'wardrobe_id': wardrobeId,
      'image_url': imageUrl,
      if (processedImageUrl != null) 'processed_image_url': processedImageUrl,
      'has_processed_image': hasProcessedImage,
      'season': _normalizeSeason(season),
      'placement': placement,
      'color_tags': _colorTagsPayload(colorTags),
      'cloth_type': clothType,
      'category': category,
      'occasions': occasions,
      'visibility': visibility,
      if (aiDetected != null) 'ai_detected': aiDetected,
    };

    final body = await LaravelApiClient.postJson(ApiConfig.clothes, payload);
    final data = LaravelApiClient.extractData(body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid cloth create response');
    }
    final clothId = data['id']?.toString() ?? '';
    if (clothId.isEmpty) throw Exception('Cloth created but id missing');
    return clothId;
  }

  /// Get cloth by ID via Laravel API.
  static Future<Cloth?> getCloth({
    required String userId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final body = await LaravelApiClient.getJson(ApiConfig.cloth(clothId));
      final data = LaravelApiClient.extractData(body);
      if (data is Map<String, dynamic>) {
        return Cloth.fromApiJson(data);
      }
      return null;
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('404') || message.contains('not found')) {
        return null;
      }
      debugPrint('Failed to get cloth: $e');
      return null;
    }
  }

  /// Get all clothes for a wardrobe
  static Future<List<Cloth>> getClothes({
    required String userId,
    required String wardrobeId,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.wardrobeClothes(wardrobeId)).replace(
        queryParameters: const {'per_page': '500'},
      );
      final body = await LaravelApiClient.getJson(uri.toString());
      return _parseClothList(LaravelApiClient.extractData(body));
    } catch (e) {
      debugPrint('Failed to get clothes: $e');
      return [];
    }
  }

  static List<Cloth> _parseClothList(dynamic data) {
    Iterable<dynamic> items;
    if (data is Map<String, dynamic> && data['data'] is List) {
      items = data['data'] as List;
    } else if (data is List) {
      items = data;
    } else {
      return [];
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(Cloth.fromApiJson)
        .toList();
  }

  /// Get all clothes for a user (across all wardrobes)
  static Future<List<Cloth>> getAllUserClothes(String userId) async {
    try {
      final uri = Uri.parse(ApiConfig.clothes).replace(
        queryParameters: const {'scope': 'mine', 'per_page': '500'},
      );
      final body = await LaravelApiClient.getJson(uri.toString());
      return _parseClothList(LaravelApiClient.extractData(body));
    } catch (e) {
      debugPrint('Failed to get all user clothes: $e');
      return [];
    }
  }

  /// Update cloth
  static Future<void> updateCloth({
    required String userId,
    required String wardrobeId,
    required String clothId,
    Map<String, dynamic>? updates,
    Cloth? cloth,
    File? newImageFile,
  }) async {
    try {
      if (newImageFile != null) {
        // Upload new image
        final imageUrl = await StorageService.uploadClothImage(
          userId: userId,
          wardrobeId: wardrobeId,
          clothId: clothId,
          imageFile: newImageFile,
        );
        updates ??= {};
        updates['imageUrl'] = imageUrl;
      }

      if (cloth != null) {
        final clothData = cloth.toJson();
        clothData['updatedAt'] = FieldValue.serverTimestamp();
        // Don't update likesCount and commentsCount (managed by Cloud Functions)
        clothData.remove('likesCount');
        clothData.remove('commentsCount');

        await _firestore
            .collection(_clothesPath(userId, wardrobeId))
            .doc(clothId)
            .update(clothData);

        // Also update top-level collection
        await _firestore.collection('clothes').doc(clothId).update(clothData);
      } else if (updates != null) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        // Don't allow updating likesCount and commentsCount
        updates.remove('likesCount');
        updates.remove('commentsCount');

        await _firestore
            .collection(_clothesPath(userId, wardrobeId))
            .doc(clothId)
            .update(updates);

        // Also update top-level collection
        await _firestore.collection('clothes').doc(clothId).update(updates);
      }
    } catch (e) {
      debugPrint('Failed to update cloth: $e');
      rethrow;
    }
  }

  /// Move cloth to a different wardrobe
  static Future<void> moveClothToWardrobe({
    required String userId,
    required String oldWardrobeId,
    required String newWardrobeId,
    required String clothId,
  }) async {
    try {
      // Get the cloth from old wardrobe
      final cloth = await getCloth(
        userId: userId,
        wardrobeId: oldWardrobeId,
        clothId: clothId,
      );

      if (cloth == null) {
        throw Exception('Cloth not found');
      }

      // Create cloth data with new wardrobe ID
      final clothData = cloth.toJson();
      clothData['wardrobeId'] = newWardrobeId;
      clothData['updatedAt'] = FieldValue.serverTimestamp();

      // Use batch to ensure atomicity
      final batch = _firestore.batch();

      // Delete from old wardrobe subcollection
      final oldClothRef = _firestore
          .collection(_clothesPath(userId, oldWardrobeId))
          .doc(clothId);
      batch.delete(oldClothRef);

      // Add to new wardrobe subcollection
      final newClothRef = _firestore
          .collection(_clothesPath(userId, newWardrobeId))
          .doc(clothId);
      batch.set(newClothRef, clothData);

      // Update top-level collection
      final topLevelRef = _firestore.collection('clothes').doc(clothId);
      batch.update(topLevelRef, {
        'wardrobeId': newWardrobeId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (kDebugMode) {
        debugPrint(
            'Cloth moved from wardrobe $oldWardrobeId to $newWardrobeId');
      }
    } catch (e) {
      debugPrint('Failed to move cloth: $e');
      rethrow;
    }
  }

  /// Delete cloth via Laravel API.
  static Future<void> deleteCloth({
    required String userId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      await LaravelApiClient.deleteJson(ApiConfig.cloth(clothId));
      if (kDebugMode) debugPrint('Cloth deleted via Laravel: $clothId');
    } catch (e) {
      debugPrint('Failed to delete cloth: $e');
      rethrow;
    }
  }

  /// Mark cloth as worn today via Laravel API.
  static Future<void> markAsWornToday({
    required String userId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      await LaravelApiClient.postJson(
        ApiConfig.clothWearHistory(clothId),
        {
          'worn_at': DateTime.now().toIso8601String(),
          'source': 'manual',
        },
      );
    } catch (e) {
      debugPrint('Failed to mark as worn: $e');
      rethrow;
    }
  }

  /// Remove today's worn entry (undo mark as worn)
  static Future<DateTime?> unmarkWornToday({
    required String userId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final historyRef = _firestore
          .collection(_clothesPath(userId, wardrobeId))
          .doc(clothId)
          .collection('wearHistory');

      // Find today's wear entry
      final todayEntry = await historyRef
          .where('wornAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .orderBy('wornAt', descending: true)
          .limit(1)
          .get();

      if (todayEntry.docs.isEmpty) {
        // Nothing to remove, simply return the current latest wornAt
        final latestSnapshot =
            await historyRef.orderBy('wornAt', descending: true).limit(1).get();
        if (latestSnapshot.docs.isEmpty) {
          // No history at all
          await _updateWornAtFields(
            userId: userId,
            wardrobeId: wardrobeId,
            clothId: clothId,
            wornAt: null,
          );
          return null;
        }
        final latest =
            (latestSnapshot.docs.first.data()['wornAt'] as Timestamp).toDate();
        await _updateWornAtFields(
          userId: userId,
          wardrobeId: wardrobeId,
          clothId: clothId,
          wornAt: latest,
        );
        return latest;
      }

      // Remove today's entry
      await todayEntry.docs.first.reference.delete();

      // Determine the new latest wornAt (if any)
      final latestSnapshot =
          await historyRef.orderBy('wornAt', descending: true).limit(1).get();

      DateTime? latestWornAt;
      if (latestSnapshot.docs.isNotEmpty) {
        latestWornAt =
            (latestSnapshot.docs.first.data()['wornAt'] as Timestamp).toDate();
      }

      await _updateWornAtFields(
        userId: userId,
        wardrobeId: wardrobeId,
        clothId: clothId,
        wornAt: latestWornAt,
      );

      return latestWornAt;
    } catch (e) {
      debugPrint('Failed to unmark worn status: $e');
      rethrow;
    }
  }

  static Future<void> _updateWornAtFields({
    required String userId,
    required String wardrobeId,
    required String clothId,
    required DateTime? wornAt,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (wornAt != null) {
      updates['wornAt'] = Timestamp.fromDate(wornAt);
      // If there's a wornAt date, keep placement as OutWardrobe
      updates['placement'] = 'OutWardrobe';
    } else {
      updates['wornAt'] = FieldValue.delete();
      // If no wornAt date, set placement back to InWardrobe
      updates['placement'] = 'InWardrobe';
    }

    await _firestore
        .collection(_clothesPath(userId, wardrobeId))
        .doc(clothId)
        .update(updates);

    await _firestore.collection('clothes').doc(clothId).update(updates);
  }

  /// Like cloth via Laravel API.
  static Future<void> likeCloth({
    required String userId,
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      await LaravelApiClient.postJson(ApiConfig.clothLikes(clothId), {});

      if (ownerId != userId) {
        PushNotificationService.sendClothLikeNotification(
          recipientUserId: ownerId,
          likerUserId: userId,
          clothId: clothId,
          clothOwnerId: ownerId,
          clothWardrobeId: wardrobeId,
        ).catchError((e) {
          debugPrint('Failed to send cloth like notification: $e');
        });
      }
    } catch (e) {
      if (e.toString().contains('409') || e.toString().contains('already liked')) {
        return;
      }
      debugPrint('Failed to like cloth: $e');
      rethrow;
    }
  }

  /// Unlike cloth via Laravel API.
  static Future<void> unlikeCloth({
    required String userId,
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      await LaravelApiClient.deleteJson(ApiConfig.clothLikes(clothId));
    } catch (e) {
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        return;
      }
      debugPrint('Failed to unlike cloth: $e');
      rethrow;
    }
  }

  /// Check if user has liked cloth via Laravel API.
  static Future<bool> hasLiked({
    required String userId,
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final body = await LaravelApiClient.getJson(ApiConfig.clothLikes(clothId));
      final data = LaravelApiClient.extractData(body);
      if (data is List) {
        return data.any((like) {
          if (like is! Map<String, dynamic>) return false;
          return like['user_id']?.toString() == userId ||
              like['userId']?.toString() == userId;
        });
      }
      return false;
    } catch (e) {
      debugPrint('Failed to check like status: $e');
      return false;
    }
  }

  /// Get like count via Laravel API (from cloth or likes list).
  static Future<int> getLikeCount({
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final cloth = await getCloth(
        userId: ownerId,
        wardrobeId: wardrobeId,
        clothId: clothId,
      );
      if (cloth != null) return cloth.likesCount;

      final body = await LaravelApiClient.getJson(ApiConfig.clothLikes(clothId));
      final data = LaravelApiClient.extractData(body);
      if (data is List) return data.length;
      return 0;
    } catch (e) {
      debugPrint('Failed to get like count: $e');
      return 0;
    }
  }

  /// Add comment to cloth (Laravel API)
  static Future<String> addComment({
    required String userId,
    required String ownerId,
    required String wardrobeId,
    required String clothId,
    required String text,
  }) async {
    try {
      final isSafe = await ContentFilterService.isContentSafe(text);
      if (!isSafe) {
        throw Exception(
            'Your comment contains inappropriate content and cannot be posted. Please revise your message.');
      }

      final body = await LaravelApiClient.postJson(
        ApiConfig.clothComments(clothId),
        {'text': text},
      );
      final data = LaravelApiClient.extractData(body);
      if (data is Map<String, dynamic>) {
        final id = data['id']?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
      throw Exception(body['message']?.toString() ?? 'Failed to add comment');
    } catch (e) {
      debugPrint('Failed to add comment: $e');
      rethrow;
    }
  }

  /// Get comments for cloth (Laravel API)
  static Future<List<Comment>> getComments({
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final body =
          await LaravelApiClient.getJson(ApiConfig.clothComments(clothId));
      final data = LaravelApiClient.extractData(body);
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic> && data['data'] is List) {
        list = data['data'] as List;
      } else {
        list = const [];
      }
      return list
          .whereType<Map>()
          .map((e) => Comment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Failed to get comments: $e');
      return [];
    }
  }

  /// Delete comment (Laravel API)
  static Future<void> deleteComment({
    required String userId,
    required String ownerId,
    required String wardrobeId,
    required String clothId,
    required String commentId,
  }) async {
    try {
      await LaravelApiClient.deleteJson(ApiConfig.comment(commentId));
    } catch (e) {
      debugPrint('Failed to delete comment: $e');
      rethrow;
    }
  }

  /// Comment count from Laravel cloth record / comments list length
  static Future<int> getCommentCount({
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final comments = await getComments(
        ownerId: ownerId,
        wardrobeId: wardrobeId,
        clothId: clothId,
      );
      return comments.length;
    } catch (e) {
      debugPrint('Failed to get comment count: $e');
      return 0;
    }
  }

  /// Stream clothes for real-time updates
  static Stream<List<Cloth>> watchClothes({
    required String userId,
    required String wardrobeId,
  }) {
    return _firestore
        .collection(_clothesPath(userId, wardrobeId))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Cloth.fromJson(doc.data(), doc.id))
            .toList());
  }

  /// Stream all user clothes for real-time updates
  static Stream<List<Cloth>> watchAllUserClothes(String userId) {
    return _firestore
        .collection('clothes')
        .where('ownerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Cloth.fromJson(doc.data(), doc.id))
            .toList());
  }

  /// Get wear history for cloth via Laravel API.
  static Future<List<WearHistoryEntry>> getWearHistory({
    required String userId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.clothWearHistory(clothId)).replace(
        queryParameters: const {'per_page': '100'},
      );
      final body = await LaravelApiClient.getJson(uri.toString());
      final data = LaravelApiClient.extractData(body);

      Iterable<dynamic> items;
      if (data is Map<String, dynamic> && data['data'] is List) {
        items = data['data'] as List;
      } else if (data is List) {
        items = data;
      } else {
        return [];
      }

      return items
          .whereType<Map<String, dynamic>>()
          .map(WearHistoryEntry.fromApiJson)
          .toList();
    } catch (e) {
      debugPrint('Failed to get wear history: $e');
      return [];
    }
  }
}
