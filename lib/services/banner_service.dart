import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/banner.dart';

/// Service for fetching banners from the API
class BannerService {
  /// Get banner API base URL from environment variables
  /// Falls back to default if not set
  static String get baseUrl {
    const fallback = 'https://www.wardrobe.chat/api';
    try {
      if (!dotenv.isInitialized) return fallback;
      final v = dotenv.env['BANNER_API_BASE_URL'];
      if (v == null || v.trim().isEmpty) return fallback;
      return v.trim();
    } catch (_) {
      // In some situations (e.g. if .env asset failed to load), flutter_dotenv throws
      // NotInitializedError when accessing dotenv.env. Banners are optional, so fall back.
      return fallback;
    }
  }

  /// Get banners for a specific location
  /// 
  /// [location] can be: 'login', 'wardrobe_list', or 'home_screen'
  Future<List<Banner>> getBannersByLocation(String location) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/banners/location/$location'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        if (jsonData['success'] == true) {
          final List<dynamic> banners = jsonData['data'] as List<dynamic>;
          return banners.map((banner) => Banner.fromJson(banner as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching banners by location: $e');
      return [];
    }
  }

  /// Get banners with optional filters
  /// 
  /// [location] can be: 'login', 'wardrobe_list', or 'home_screen'
  /// [type] can be: '320x100' or '1080x1920'
  Future<List<Banner>> getBanners({
    String? location,
    String? type,
  }) async {
    try {
      String url = '$baseUrl/banners?';
      if (location != null) url += 'location=$location&';
      if (type != null) url += 'type=$type&';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        if (jsonData['success'] == true) {
          final List<dynamic> banners = jsonData['data'] as List<dynamic>;
          return banners.map((banner) => Banner.fromJson(banner as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching banners: $e');
      return [];
    }
  }
}
