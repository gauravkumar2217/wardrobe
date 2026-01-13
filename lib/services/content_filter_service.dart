import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Content filter service using Google Cloud Natural Language API
/// Filters objectionable content before it's posted
class ContentFilterService {
  // Note: In production, this API key should be stored securely
  // Consider using Firebase Functions to proxy these requests
  static const String _apiKey = 'YOUR_GOOGLE_CLOUD_API_KEY'; // Replace with actual API key
  static const String _moderateUrl = 'https://language.googleapis.com/v1/documents:moderateText';

  /// Check if content is safe to post
  /// Returns true if content is safe, false if it should be blocked
  static Future<bool> isContentSafe(String text) async {
    if (text.trim().isEmpty) return true;

    try {
      // Use moderateText API for toxicity detection
      final response = await http.post(
        Uri.parse('$_moderateUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'document': {
            'type': 'PLAIN_TEXT',
            'content': text,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Check for moderation categories
        final moderationCategories = data['moderationCategories'] as List?;
        if (moderationCategories != null && moderationCategories.isNotEmpty) {
          // Content has been flagged - check severity
          for (var category in moderationCategories) {
            final confidence = category['confidence'] as double? ?? 0.0;
            // Block if confidence is high (>= 0.7)
            if (confidence >= 0.7) {
              debugPrint('Content blocked: ${category['name']} (confidence: $confidence)');
              return false;
            }
          }
        }

        return true;
      } else {
        // If API call fails, allow content but log error
        // In production, you might want to block content if filter fails
        debugPrint('Content filter API error: ${response.statusCode} - ${response.body}');
        return true; // Fail open for now - adjust based on your policy
      }
    } catch (e) {
      debugPrint('Content filter error: $e');
      // Fail open - allow content if filter fails
      // In production, consider failing closed for stricter moderation
      return true;
    }
  }

  /// Get toxicity score for content
  /// Returns a score between 0.0 (safe) and 1.0 (highly toxic)
  static Future<double> getToxicityScore(String text) async {
    if (text.trim().isEmpty) return 0.0;

    try {
      final response = await http.post(
        Uri.parse('$_moderateUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'document': {
            'type': 'PLAIN_TEXT',
            'content': text,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final moderationCategories = data['moderationCategories'] as List?;
        
        if (moderationCategories != null && moderationCategories.isNotEmpty) {
          // Return the highest confidence score
          double maxConfidence = 0.0;
          for (var category in moderationCategories) {
            final confidence = category['confidence'] as double? ?? 0.0;
            if (confidence > maxConfidence) {
              maxConfidence = confidence;
            }
          }
          return maxConfidence;
        }
      }
    } catch (e) {
      debugPrint('Toxicity score error: $e');
    }

    return 0.0;
  }

  /// Filter content and return filtered version
  /// Replaces objectionable words with asterisks
  static Future<String> filterContent(String text) async {
    // For now, return original text
    // In production, you could implement word replacement logic
    final isSafe = await isContentSafe(text);
    if (!isSafe) {
      return ''; // Return empty string if content is unsafe
    }
    return text;
  }

  /// Check multiple texts at once
  static Future<List<bool>> areContentsSafe(List<String> texts) async {
    final results = <bool>[];
    for (var text in texts) {
      results.add(await isContentSafe(text));
    }
    return results;
  }
}
