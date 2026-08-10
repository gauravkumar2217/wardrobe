import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Content filter using Google Cloud Natural Language ModerateText.
/// If the API key cannot call Language API, filtering is disabled (fail open).
class ContentFilterService {
  static const String _moderateUrl =
      'https://language.googleapis.com/v1/documents:moderateText';

  /// After a hard API-key block, stop calling Google on every message.
  static bool _disabled = false;
  static bool _loggedDisable = false;

  static String? get _apiKey => dotenv.env['GOOGLE_CLOUD_API_KEY'];

  /// Explicit opt-in: set CONTENT_FILTER_ENABLED=true in .env to use the API.
  /// Default is off so chat is not slowed / flooded by 403s when the key
  /// cannot access language.googleapis.com.
  static bool get _enabledInEnv {
    final v = dotenv.env['CONTENT_FILTER_ENABLED']?.trim().toLowerCase();
    return v == 'true' || v == '1' || v == 'yes';
  }

  static Future<bool> isContentSafe(String text) async {
    if (text.trim().isEmpty) return true;
    if (_disabled || !_enabledInEnv) return true;

    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      return true;
    }

    try {
      final response = await http.post(
        Uri.parse('$_moderateUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
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
          for (final category in moderationCategories) {
            final confidence = (category['confidence'] as num?)?.toDouble() ?? 0.0;
            if (confidence >= 0.7) {
              debugPrint(
                  'Content blocked: ${category['name']} (confidence: $confidence)');
              return false;
            }
          }
        }
        return true;
      }

      _disableIfApiKeyBlocked(response.statusCode, response.body);
      return true;
    } catch (e) {
      debugPrint('Content filter error: $e');
      return true;
    }
  }

  static void _disableIfApiKeyBlocked(int statusCode, String body) {
    final blocked = statusCode == 403 &&
        (body.contains('API_KEY_SERVICE_BLOCKED') ||
            body.contains('PERMISSION_DENIED') ||
            body.contains('are blocked'));
    if (!blocked && statusCode != 403) {
      if (kDebugMode) {
        debugPrint('Content filter API error: $statusCode');
      }
      return;
    }

    _disabled = true;
    if (!_loggedDisable) {
      _loggedDisable = true;
      debugPrint(
        'Content filter disabled: Google Language API blocked for this API key '
        '(API_KEY_SERVICE_BLOCKED). Chat messages will still send. '
        'Fix: Cloud Console → Credentials → your key → API restrictions → '
        'include "Cloud Natural Language API", or set CONTENT_FILTER_ENABLED=false.',
      );
    }
  }

  static Future<double> getToxicityScore(String text) async {
    if (!_enabledInEnv || _disabled || text.trim().isEmpty) return 0.0;
    // Reuse safety check path only when enabled; score not critical for chat.
    final safe = await isContentSafe(text);
    return safe ? 0.0 : 1.0;
  }

  static Future<String> filterContent(String text) async {
    final isSafe = await isContentSafe(text);
    return isSafe ? text : '';
  }

  static Future<List<bool>> areContentsSafe(List<String> texts) async {
    final results = <bool>[];
    for (final text in texts) {
      results.add(await isContentSafe(text));
    }
    return results;
  }
}
