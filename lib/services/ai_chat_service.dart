import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import 'wardrobe_service.dart';
import 'cloth_service.dart';

/// AI Chat Service for conversational wardrobe advice
/// Supports OpenAI GPT and Google Gemini
class AIChatService {
  // API Keys - should be stored in environment variables
  static const String? _openaiApiKey = null; // Set your OpenAI API key here
  static const String? _geminiApiKey = null; // Set your Gemini API key here

  /// Get chat response from OpenAI
  static Future<String> getOpenAIResponse(
    String userMessage,
    List<ChatMessage> conversationHistory,
    String userId,
  ) async {
    if (_openaiApiKey == null) {
      throw Exception('OpenAI API key not configured');
    }

    try {
      // Build context from user's wardrobe data
      final context = await _buildWardrobeContext(userId);

      // Build messages for API
      final messages = [
        {
          'role': 'system',
          'content': '''You are a helpful wardrobe assistant. You help users with:
- Outfit suggestions based on their wardrobe
- Style advice and tips
- Color coordination help
- Occasion-based recommendations
- Answering questions about their clothes

User's wardrobe context:
$context

Be friendly, helpful, and concise. Keep responses under 200 words unless asked for more detail.''',
        },
        ...conversationHistory.map((msg) => {
              'role': msg.role,
              'content': msg.content,
            }),
        {
          'role': 'user',
          'content': userMessage,
        },
      ];

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openaiApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': messages,
          'max_tokens': 300,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      }

      throw Exception('OpenAI API error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to get AI response: $e');
    }
  }

  /// Get chat response from Google Gemini
  static Future<String> getGeminiResponse(
    String userMessage,
    List<ChatMessage> conversationHistory,
    String userId,
  ) async {
    if (_geminiApiKey == null) {
      throw Exception('Gemini API key not configured');
    }

    try {
      // Build context from user's wardrobe data
      final context = await _buildWardrobeContext(userId);

      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$_geminiApiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text': '''You are a helpful wardrobe assistant. You help users with:
- Outfit suggestions based on their wardrobe
- Style advice and tips
- Color coordination help
- Occasion-based recommendations
- Answering questions about their clothes

User's wardrobe context:
$context

Be friendly, helpful, and concise. Keep responses under 200 words unless asked for more detail.

User: $userMessage'''
                }
              ]
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      }

      throw Exception('Gemini API error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to get AI response: $e');
    }
  }

  /// Get AI response with fallback to multiple providers
  static Future<String> getResponse(
    String userMessage,
    List<ChatMessage> conversationHistory,
    String userId,
  ) async {
    // Try OpenAI first, fallback to Gemini
    try {
      if (_openaiApiKey != null) {
        return await getOpenAIResponse(userMessage, conversationHistory, userId);
      }
    } catch (e) {
      // Fallback to Gemini
    }

    if (_geminiApiKey != null) {
      return await getGeminiResponse(userMessage, conversationHistory, userId);
    }

    // Fallback response if no API keys configured
    return '''I'm your wardrobe assistant! To enable AI features, please configure an API key.

I can help you with:
- Outfit suggestions
- Style advice
- Color coordination
- Occasion-based recommendations

For now, here's a basic tip: Try to match colors that complement each other, and consider the occasion when choosing your outfit!''';
  }

  /// Build context string from user's wardrobe data
  static Future<String> _buildWardrobeContext(String userId) async {
    try {
      final wardrobes = await WardrobeService.getUserWardrobes(userId);
      
      if (wardrobes.isEmpty) {
        return 'User has no wardrobes yet.';
      }

      final buffer = StringBuffer();
      buffer.writeln('User has ${wardrobes.length} wardrobe(s):');
      
      for (final wardrobe in wardrobes) {
        buffer.writeln('- ${wardrobe.title} (${wardrobe.season} season, ${wardrobe.clothCount} items)');
        
        // Get clothes for this wardrobe
        final clothes = await ClothService.getClothes(userId, wardrobe.id);
        if (clothes.isNotEmpty) {
          buffer.writeln('  Items:');
          final typeCounts = <String, int>{};
          final colorCounts = <String, int>{};
          
          for (final cloth in clothes) {
            typeCounts[cloth.type] = (typeCounts[cloth.type] ?? 0) + 1;
            colorCounts[cloth.color] = (colorCounts[cloth.color] ?? 0) + 1;
          }
          
          buffer.writeln('    Types: ${typeCounts.keys.join(", ")}');
          buffer.writeln('    Colors: ${colorCounts.keys.join(", ")}');
        }
      }
      
      return buffer.toString();
    } catch (e) {
      return 'Unable to load wardrobe context.';
    }
  }
}

