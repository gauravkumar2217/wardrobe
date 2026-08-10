import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'laravel_api_client.dart';

/// User blocking via Laravel API (MySQL). No Firestore.
class BlockService {
  /// Block a user
  static Future<void> blockUser({
    required String blockerId,
    required String blockedUserId,
    String? reason,
  }) async {
    if (blockerId == blockedUserId) {
      throw Exception('Cannot block yourself');
    }
    await LaravelApiClient.postJson(ApiConfig.blocks, {
      'blocked_user_id': blockedUserId,
      if (reason != null) 'reason': reason,
    });
    debugPrint('User blocked via API: $blockedUserId by $blockerId');
  }

  /// Unblock a user
  static Future<void> unblockUser({
    required String blockerId,
    required String blockedUserId,
  }) async {
    await LaravelApiClient.deleteJson(ApiConfig.blockUser(blockedUserId));
    debugPrint('User unblocked via API: $blockedUserId by $blockerId');
  }

  static Future<bool> isUserBlocked({
    required String blockerId,
    required String blockedUserId,
  }) async {
    try {
      final body =
          await LaravelApiClient.getJson(ApiConfig.blockCheck(blockedUserId));
      final data = LaravelApiClient.extractData(body);
      if (data is Map) {
        return data['blocked'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to check if user is blocked: $e');
      return false;
    }
  }

  static Future<List<String>> getBlockedUserIds(String userId) async {
    try {
      final body = await LaravelApiClient.getJson(ApiConfig.blocks);
      final data = LaravelApiClient.extractData(body);
      if (data is List) {
        return data.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Failed to get blocked user IDs: $e');
      return [];
    }
  }

  /// Polling stream (replaces Firestore snapshots).
  static Stream<List<String>> watchBlockedUserIds(String userId) async* {
    yield await getBlockedUserIds(userId);
    await for (final _ in Stream.periodic(const Duration(seconds: 60))) {
      try {
        yield await getBlockedUserIds(userId);
      } catch (e) {
        if (kDebugMode) debugPrint('watchBlockedUserIds poll error: $e');
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getBlockedUsers(
      String userId) async {
    final ids = await getBlockedUserIds(userId);
    return ids
        .map((id) => {
              'blockedUserId': id,
              'blockedAt': null,
              'reason': null,
            })
        .toList();
  }

  static Future<bool> areUsersBlocked({
    required String userId1,
    required String userId2,
  }) async {
    try {
      final a = await isUserBlocked(
        blockerId: userId1,
        blockedUserId: userId2,
      );
      final b = await isUserBlocked(
        blockerId: userId2,
        blockedUserId: userId1,
      );
      return a || b;
    } catch (e) {
      debugPrint('Failed to check bidirectional block: $e');
      return false;
    }
  }
}
