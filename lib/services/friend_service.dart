import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/friend_request.dart';
import 'laravel_api_client.dart';

/// Friend service — Laravel API (MySQL). No Firestore.
class FriendService {
  static List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      final nested = data['data'];
      if (nested is List) return nested;
    }
    return const [];
  }

  static String? _userIdFromFriendEntry(dynamic entry) {
    if (entry is String) return entry;
    if (entry is Map<String, dynamic>) {
      return entry['id']?.toString() ??
          entry['friend_id']?.toString() ??
          entry['friendId']?.toString();
    }
    return null;
  }

  /// Send friend request. Returns request id.
  static Future<String> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
  }) async {
    if (fromUserId == toUserId) {
      throw Exception('Cannot send friend request to yourself');
    }

    final body = await LaravelApiClient.postJson(
      ApiConfig.friendRequests,
      {'to_user_id': toUserId},
    );
    final data = LaravelApiClient.extractData(body);
    if (data is Map<String, dynamic>) {
      final id = data['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    throw Exception(body['message']?.toString() ?? 'Failed to send friend request');
  }

  static Future<void> acceptFriendRequest(String requestId) async {
    if (requestId.isEmpty) {
      throw Exception('Friend request ID cannot be empty');
    }
    await LaravelApiClient.postJson(
      ApiConfig.friendRequestAccept(requestId),
      const {},
    );
  }

  static Future<void> rejectFriendRequest(String requestId) async {
    await LaravelApiClient.postJson(
      ApiConfig.friendRequestReject(requestId),
      const {},
    );
  }

  static Future<void> cancelFriendRequest(String requestId) async {
    await LaravelApiClient.postJson(
      ApiConfig.friendRequestCancel(requestId),
      const {},
    );
  }

  /// [type]: `incoming` | `outgoing` | `all`
  static Future<List<FriendRequest>> getFriendRequests({
    required String userId,
    String type = 'all',
  }) async {
    if (type == 'incoming') {
      final body =
          await LaravelApiClient.getJson(ApiConfig.friendRequestsPending);
      final list = _asList(LaravelApiClient.extractData(body));
      return list
          .whereType<Map>()
          .map((e) => FriendRequest.fromApiJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final body = await LaravelApiClient.getJson(ApiConfig.friendRequests);
    final list = _asList(LaravelApiClient.extractData(body));
    final all = list
        .whereType<Map>()
        .map((e) => FriendRequest.fromApiJson(Map<String, dynamic>.from(e)))
        .toList();

    if (type == 'outgoing') {
      return all
          .where((r) => r.fromUserId == userId && r.isPending)
          .toList();
    }
    if (type == 'incoming') {
      return all
          .where((r) => r.toUserId == userId && r.isPending)
          .toList();
    }
    return all;
  }

  /// Returns friend user ids.
  static Future<List<String>> getFriends(String userId) async {
    final body = await LaravelApiClient.getJson(ApiConfig.friends);
    final list = _asList(LaravelApiClient.extractData(body));
    final ids = <String>[];
    for (final entry in list) {
      final id = _userIdFromFriendEntry(entry);
      if (id != null && id.isNotEmpty && id != userId) {
        ids.add(id);
      }
    }
    return ids;
  }

  static Future<bool> checkFriendship(String userId1, String userId2) async {
    try {
      final friends = await getFriends(userId1);
      return friends.contains(userId2);
    } catch (e) {
      debugPrint('checkFriendship failed: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> checkFriendRequestStatus({
    required String userId1,
    required String userId2,
  }) async {
    try {
      final requests = await getFriendRequests(userId: userId1, type: 'all');
      for (final r in requests) {
        if (!r.isPending) continue;
        if ((r.fromUserId == userId1 && r.toUserId == userId2) ||
            (r.fromUserId == userId2 && r.toUserId == userId1)) {
          return {'status': r.status, 'requestId': r.id};
        }
      }
      return {'status': 'none', 'requestId': null};
    } catch (e) {
      debugPrint('checkFriendRequestStatus failed: $e');
      return {'status': 'none', 'requestId': null};
    }
  }

  static Future<void> removeFriend({
    required String userId,
    required String friendId,
  }) async {
    await LaravelApiClient.deleteJson(ApiConfig.friend(friendId));
  }

  /// Light polling stream (replaces Firestore watch).
  static Stream<List<String>> watchFriends(String userId) async* {
    yield await getFriends(userId);
    await for (final _ in Stream.periodic(const Duration(seconds: 20))) {
      try {
        yield await getFriends(userId);
      } catch (e) {
        if (kDebugMode) debugPrint('watchFriends poll error: $e');
      }
    }
  }

  static Stream<List<FriendRequest>> watchFriendRequests({
    required String userId,
    String type = 'incoming',
  }) async* {
    yield await getFriendRequests(userId: userId, type: type);
    await for (final _ in Stream.periodic(const Duration(seconds: 20))) {
      try {
        yield await getFriendRequests(userId: userId, type: type);
      } catch (e) {
        if (kDebugMode) debugPrint('watchFriendRequests poll error: $e');
      }
    }
  }
}
