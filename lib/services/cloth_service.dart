import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/cloth.dart';
import 'laravel_api_client.dart';
import 'cloth_detection_service.dart';
import 'storage_service.dart';
import 'push_notification_service.dart';
import 'content_filter_service.dart';
import 'background_removal_service.dart';

/// Cloth service for managing clothes via Laravel API.
class ClothService {
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

  /// Update cloth via Laravel API.
  static Future<void> updateCloth({
    required String userId,
    required String wardrobeId,
    required String clothId,
    Map<String, dynamic>? updates,
    Cloth? cloth,
    File? newImageFile,
  }) async {
    try {
      final payload = <String, dynamic>{};

      if (newImageFile != null) {
        final imageUrl = await StorageService.uploadClothImage(
          userId: userId,
          wardrobeId: wardrobeId,
          clothId: clothId,
          imageFile: newImageFile,
        );
        payload['image_url'] = imageUrl;
      }

      if (cloth != null) {
        payload.addAll(_clothToUpdatePayload(cloth));
      } else if (updates != null) {
        payload.addAll(_mapUpdatesToApi(updates));
      }

      if (payload.isEmpty) return;

      await LaravelApiClient.putJson(ApiConfig.cloth(clothId), payload);
    } catch (e) {
      debugPrint('Failed to update cloth: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> _clothToUpdatePayload(Cloth cloth) {
    return {
      'season': _normalizeSeason(cloth.season),
      'placement': cloth.placement,
      if (_placementPayload(cloth.placementDetails) != null)
        'placement_details': _placementPayload(cloth.placementDetails),
      'color_tags': _colorTagsPayload(cloth.colorTags),
      'cloth_type': cloth.clothType,
      'category': cloth.category,
      'occasions': cloth.occasions,
      'visibility': cloth.visibility,
      if (cloth.wardrobeId.isNotEmpty) 'wardrobe_id': cloth.wardrobeId,
    };
  }

  static Map<String, dynamic> _mapUpdatesToApi(Map<String, dynamic> updates) {
    final payload = <String, dynamic>{};
    void put(String apiKey, dynamic value) {
      if (value != null) payload[apiKey] = value;
    }

    put('season', updates['season']);
    put('placement', updates['placement']);
    put('placement_details', updates['placement_details'] ?? updates['placementDetails']);
    put('color_tags', updates['color_tags'] ?? updates['colorTags']);
    put('cloth_type', updates['cloth_type'] ?? updates['clothType']);
    put('category', updates['category']);
    put('occasions', updates['occasions']);
    put('visibility', updates['visibility']);
    put('image_url', updates['image_url'] ?? updates['imageUrl']);
    put('wardrobe_id', updates['wardrobe_id'] ?? updates['wardrobeId']);
    return payload;
  }

  /// Move cloth to a different wardrobe via Laravel API.
  static Future<void> moveClothToWardrobe({
    required String userId,
    required String oldWardrobeId,
    required String newWardrobeId,
    required String clothId,
  }) async {
    try {
      await LaravelApiClient.putJson(ApiConfig.cloth(clothId), {
        'wardrobe_id': newWardrobeId,
      });
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

  /// Remove today's worn entry (undo mark as worn) via Laravel API.
  static Future<DateTime?> unmarkWornToday({
    required String userId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final body = await LaravelApiClient.deleteJson(
        ApiConfig.clothWearHistoryToday(clothId),
      );
      final data = LaravelApiClient.extractData(body);
      if (data is Map<String, dynamic>) {
        final wornAtRaw = data['worn_at'] ?? data['wornAt'];
        if (wornAtRaw == null) return null;
        if (wornAtRaw is String && wornAtRaw.isNotEmpty) {
          return DateTime.parse(wornAtRaw);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Failed to unmark worn status: $e');
      rethrow;
    }
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

  /// Poll clothes periodically (replaces Firestore snapshots).
  static Stream<List<Cloth>> watchClothes({
    required String userId,
    required String wardrobeId,
  }) async* {
    yield await getClothes(userId: userId, wardrobeId: wardrobeId);
    while (true) {
      await Future.delayed(const Duration(seconds: 30));
      yield await getClothes(userId: userId, wardrobeId: wardrobeId);
    }
  }

  /// Poll all user clothes periodically.
  static Stream<List<Cloth>> watchAllUserClothes(String userId) async* {
    yield await getAllUserClothes(userId);
    while (true) {
      await Future.delayed(const Duration(seconds: 30));
      yield await getAllUserClothes(userId);
    }
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
