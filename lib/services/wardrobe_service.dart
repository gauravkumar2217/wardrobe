import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/wardrobe.dart';
import 'laravel_api_client.dart';

/// Wardrobe service backed by Laravel API.
class WardrobeService {
  static Wardrobe _parseWardrobe(Map<String, dynamic> json) =>
      Wardrobe.fromApiJson(json);

  static List<Wardrobe> _parseList(dynamic data) {
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(_parseWardrobe)
        .toList();
  }

  /// Create wardrobe
  static Future<String> createWardrobe({
    required String userId,
    required String name,
    required String location,
  }) async {
    try {
      final body = await LaravelApiClient.postJson(
        ApiConfig.wardrobes,
        {'name': name, 'location': location},
      );
      final data = LaravelApiClient.extractData(body);
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid wardrobe response');
      }
      final id = data['id']?.toString() ?? '';
      if (kDebugMode) debugPrint('Wardrobe created via Laravel: $id');
      return id;
    } catch (e) {
      debugPrint('Failed to create wardrobe: $e');
      rethrow;
    }
  }

  /// Get wardrobe by ID
  static Future<Wardrobe?> getWardrobe({
    required String userId,
    required String wardrobeId,
  }) async {
    try {
      final body = await LaravelApiClient.getJson(ApiConfig.wardrobe(wardrobeId));
      final data = LaravelApiClient.extractData(body);
      if (data is Map<String, dynamic>) return _parseWardrobe(data);
      return null;
    } catch (e) {
      debugPrint('Failed to get wardrobe: $e');
      return null;
    }
  }

  /// Get all wardrobes for a user
  static Future<List<Wardrobe>> getUserWardrobes(String userId) async {
    try {
      final body = await LaravelApiClient.getJson(ApiConfig.wardrobes);
      return _parseList(LaravelApiClient.extractData(body));
    } catch (e) {
      debugPrint('Failed to get user wardrobes: $e');
      return [];
    }
  }

  /// Update wardrobe
  static Future<void> updateWardrobe({
    required String userId,
    required String wardrobeId,
    Map<String, dynamic>? updates,
    Wardrobe? wardrobe,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (wardrobe != null) {
        payload['name'] = wardrobe.name;
        payload['location'] = wardrobe.location;
      } else if (updates != null) {
        if (updates.containsKey('name')) payload['name'] = updates['name'];
        if (updates.containsKey('location')) {
          payload['location'] = updates['location'];
        }
      }

      await LaravelApiClient.putJson(ApiConfig.wardrobe(wardrobeId), payload);
    } catch (e) {
      debugPrint('Failed to update wardrobe: $e');
      rethrow;
    }
  }

  /// Get clothes count in wardrobe
  static Future<int> getClothesCount({
    required String userId,
    required String wardrobeId,
  }) async {
    try {
      final wardrobe = await getWardrobe(userId: userId, wardrobeId: wardrobeId);
      return wardrobe?.totalItems ?? 0;
    } catch (e) {
      debugPrint('Failed to get clothes count: $e');
      return 0;
    }
  }

  /// Delete wardrobe (only if it has no clothes)
  static Future<void> deleteWardrobe({
    required String userId,
    required String wardrobeId,
  }) async {
    try {
      final count = await getClothesCount(userId: userId, wardrobeId: wardrobeId);
      if (count > 0) {
        throw Exception(
          'Wardrobe cannot be deleted because it contains $count item(s). '
          'Please move your clothes before removing the wardrobe.',
        );
      }
      await LaravelApiClient.deleteJson(ApiConfig.wardrobe(wardrobeId));
    } catch (e) {
      debugPrint('Failed to delete wardrobe: $e');
      rethrow;
    }
  }

  /// Poll wardrobes periodically (replaces Firestore real-time stream).
  static Stream<List<Wardrobe>> watchUserWardrobes(String userId) async* {
    yield await getUserWardrobes(userId);
    while (true) {
      await Future.delayed(const Duration(seconds: 30));
      yield await getUserWardrobes(userId);
    }
  }
}
