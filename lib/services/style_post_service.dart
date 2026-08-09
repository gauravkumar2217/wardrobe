import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';
import '../models/style_post.dart';
import 'laravel_api_client.dart';
import 'laravel_auth_service.dart';

class StylePostService {
  static List<dynamic> _listFromData(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return const [];
  }

  /// scope: mine | friends | all | public
  static Future<List<StylePost>> getPosts({String scope = 'all'}) async {
    final uri = Uri.parse(ApiConfig.stylePosts).replace(
      queryParameters: {'scope': scope, 'per_page': '40'},
    );
    final body = await LaravelApiClient.getJson(uri.toString());
    final data = LaravelApiClient.extractData(body);
    return _listFromData(data)
        .whereType<Map>()
        .map((e) => StylePost.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<StylePost> createPost({
    required File imageFile,
    String? caption,
    String visibility = 'friends',
  }) async {
    final token = await LaravelAuthService.ensureToken();
    final req = http.MultipartRequest('POST', Uri.parse(ApiConfig.stylePosts));
    req.headers['Accept'] = 'application/json';
    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    if (caption != null && caption.trim().isNotEmpty) {
      req.fields['caption'] = caption.trim();
    }
    req.fields['visibility'] = visibility;

    final streamed = await req.send().timeout(ApiConfig.requestTimeout);
    final responseBody = await streamed.stream.bytesToString();
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response');
    }
    if (streamed.statusCode < 200 ||
        streamed.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception(
        decoded['message']?.toString() ??
            'Failed to create style post (${streamed.statusCode})',
      );
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Missing post data');
    }
    return StylePost.fromJson(data);
  }

  static Future<void> deletePost(String postId) async {
    await LaravelApiClient.deleteJson(ApiConfig.stylePost(postId));
  }

  static Future<StylePost> like(String postId) async {
    final body =
        await LaravelApiClient.postJson(ApiConfig.stylePostLike(postId), {});
    // Reload not returned fully — caller updates locally
    LaravelApiClient.extractData(body);
    return StylePost(
      id: postId,
      userId: '',
      imageUrl: '',
      likedByMe: true,
    );
  }

  static Future<void> unlike(String postId) async {
    await LaravelApiClient.deleteJson(ApiConfig.stylePostLike(postId));
  }

  static Future<void> shareWithFriends({
    required String postId,
    required List<String> userIds,
  }) async {
    await LaravelApiClient.postJson(
      ApiConfig.stylePostShare(postId),
      {'user_ids': userIds},
    );
  }

  /// Download a remote style image to a temp file for scan → wardrobe flow.
  static Future<File> downloadImageToTemp(String imageUrl) async {
    final res = await http.get(Uri.parse(imageUrl)).timeout(
          ApiConfig.requestTimeout,
        );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to download style image');
    }
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/style_scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(res.bodyBytes);
    if (kDebugMode) {
      debugPrint('Style image saved for scan: ${file.path}');
    }
    return file;
  }
}
