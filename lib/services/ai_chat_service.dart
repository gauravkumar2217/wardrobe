import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import 'wardrobe_service.dart';
import 'cloth_service.dart';
import 'user_service.dart';

/// AI Chat Service for conversational wardrobe advice
/// Supports OpenAI GPT and Google Gemini
class AIChatService {
  // API Keys - can be configured via environment variables or build config
  // For now, set to null (AI features will be disabled)
  static String? get _openaiApiKey =>
      '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';
  static String? get _geminiApiKey => 'AIzaSyBQHIBtvLWP9spv2VF9lYrPpYqdS_gIB20';

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
          'content':
              '''You are a helpful wardrobe assistant. You help users with:
- Outfit suggestions based on their wardrobe
- Style advice and tips
- Color coordination help
- Occasion-based recommendations
- Answering questions about their clothes

IMPORTANT INSTRUCTIONS:
- You have access to the user's complete wardrobe data and profile information below
- DO NOT ask the user for their gender, name, birthday, styling preferences, or any information that is already provided in the context
- Use the provided information to give personalized suggestions directly
- If information is missing from the context, make reasonable assumptions based on available data rather than asking
- Be proactive and helpful - provide suggestions without asking unnecessary questions

User's Profile and Wardrobe Context:
$context

Be friendly, helpful, and concise. Keep responses under 200 words unless asked for more detail. Always use the provided context to give personalized advice without asking for information you already have.''',
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
        if (data['choices'] != null &&
            data['choices'].isNotEmpty &&
            data['choices'][0]['message'] != null &&
            data['choices'][0]['message']['content'] != null) {
          return data['choices'][0]['message']['content'] as String;
        }
        throw Exception('Invalid response format from OpenAI API');
      }

      // Log error details for debugging
      if (kDebugMode) {
        debugPrint('OpenAI API Error ${response.statusCode}: ${response.body}');
      }
      throw Exception('OpenAI API error: ${response.statusCode}');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('OpenAI API Exception: $e');
      }
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

      // Build system prompt with context
      final systemPrompt =
          '''You are a helpful wardrobe assistant. You help users with:
- Outfit suggestions based on their wardrobe
- Style advice and tips
- Color coordination help
- Occasion-based recommendations
- Answering questions about their clothes

IMPORTANT INSTRUCTIONS:
- You have access to the user's complete wardrobe data and profile information below
- DO NOT ask the user for their gender, name, birthday, styling preferences, or any information that is already provided in the context
- Use the provided information to give personalized suggestions directly
- If information is missing from the context, make reasonable assumptions based on available data rather than asking
- Be proactive and helpful - provide suggestions without asking unnecessary questions

User's Profile and Wardrobe Context:
$context

Be friendly, helpful, and concise. Keep responses under 200 words unless asked for more detail. Always use the provided context to give personalized advice without asking for information you already have.''';

      // Build conversation history for Gemini (with role field required)
      final contents = <Map<String, dynamic>>[];

      // Add conversation history with proper roles
      for (final msg in conversationHistory) {
        contents.add({
          'role': msg.role == 'user' ? 'user' : 'model',
          'parts': [
            {'text': msg.content}
          ]
        });
      }

      // Add current user message with system context prepended if no history
      final userMessageText = conversationHistory.isEmpty
          ? '$systemPrompt\n\nUser: $userMessage'
          : userMessage;

      contents.add({
        'role': 'user',
        'parts': [
          {'text': userMessageText}
        ]
      });

      // Use gemini-2.0-flash model with X-goog-api-key header (as per your curl example)
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent',
        ),
        headers: {
          'Content-Type': 'application/json',
          'X-goog-api-key': _geminiApiKey!,
        },
        body: jsonEncode({
          'contents': contents,
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 500,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle response structure
        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text'] as String;
        }

        throw Exception('Invalid response format from Gemini API');
      }

      // Log error details for debugging
      if (kDebugMode) {
        debugPrint('Gemini API Error ${response.statusCode}: ${response.body}');
      }
      throw Exception('Gemini API error: ${response.statusCode}');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Gemini API Exception: $e');
      }
      throw Exception('Failed to get AI response: $e');
    }
  }

  /// Get AI response with fallback to multiple providers
  static Future<String> getResponse(
    String userMessage,
    List<ChatMessage> conversationHistory,
    String userId,
  ) async {
    // Try Gemini first (free tier available), fallback to OpenAI
    if (_geminiApiKey != null) {
      try {
        if (kDebugMode) {
          debugPrint('Attempting Gemini API call...');
        }
        final response =
            await getGeminiResponse(userMessage, conversationHistory, userId);
        // Ensure response doesn't contain fallback message text
        if (response.contains('configure an API key') ||
            response.contains('To enable AI features')) {
          // If somehow fallback text got in, try OpenAI
          throw Exception('Invalid response format');
        }
        return response;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Gemini failed, falling back to OpenAI: $e');
        }
        // Fallback to OpenAI if Gemini fails
      }
    }

    // Fallback to OpenAI
    if (_openaiApiKey != null) {
      try {
        if (kDebugMode) {
          debugPrint('Attempting OpenAI API call...');
        }
        return await getOpenAIResponse(
            userMessage, conversationHistory, userId);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('OpenAI failed: $e');
        }
      }
    }

    // Only show fallback if both APIs are truly unavailable
    throw Exception(
        'AI chat feature is currently unavailable. To enable this feature, please configure API keys in the app settings.');
  }

  /// Build context string from user's wardrobe data and profile
  static Future<String> _buildWardrobeContext(String userId) async {
    try {
      final buffer = StringBuffer();

      // Get user profile information
      final userProfile = await UserService.getUserProfile(userId);
      if (userProfile != null) {
        buffer.writeln('USER PROFILE:');
        if (userProfile.name != null && userProfile.name!.isNotEmpty) {
          buffer.writeln('Name: ${userProfile.name}');
        }
        if (userProfile.gender != null && userProfile.gender!.isNotEmpty) {
          buffer.writeln('Gender: ${userProfile.gender}');
        }
        if (userProfile.birthday != null) {
          final age = DateTime.now().year - userProfile.birthday!.year;
          buffer.writeln('Age: $age years old');
        }
        buffer.writeln('');
      }

      // Get wardrobe information
      final wardrobes = await WardrobeService.getUserWardrobes(userId);

      if (wardrobes.isEmpty) {
        buffer.writeln('WARDROBE: User has no wardrobes yet.');
        return buffer.toString();
      }

      buffer.writeln('WARDROBE INFORMATION:');
      buffer.writeln('User has ${wardrobes.length} wardrobe(s):');
      buffer.writeln('');

      for (final wardrobe in wardrobes) {
        buffer.writeln('Wardrobe: ${wardrobe.title}');
        buffer.writeln('  Location: ${wardrobe.location}');
        buffer.writeln('  Season: ${wardrobe.season}');
        buffer.writeln('  Total Items: ${wardrobe.clothCount}');

        // Get clothes for this wardrobe
        final clothes = await ClothService.getClothes(userId, wardrobe.id);
        if (clothes.isNotEmpty) {
          buffer.writeln('  Clothing Items:');

          final typeCounts = <String, int>{};
          final colorCounts = <String, int>{};
          final occasionCounts = <String, int>{};

          for (final cloth in clothes) {
            typeCounts[cloth.type] = (typeCounts[cloth.type] ?? 0) + 1;
            colorCounts[cloth.color] = (colorCounts[cloth.color] ?? 0) + 1;
            occasionCounts[cloth.occasion] =
                (occasionCounts[cloth.occasion] ?? 0) + 1;
          }

          buffer.writeln(
              '    Clothing Types: ${typeCounts.entries.map((e) => '${e.key} (${e.value})').join(", ")}');
          buffer.writeln(
              '    Colors Available: ${colorCounts.entries.map((e) => '${e.key} (${e.value})').join(", ")}');
          buffer.writeln(
              '    Occasions: ${occasionCounts.entries.map((e) => '${e.key} (${e.value})').join(", ")}');

          // Show some recent items
          final recentItems = clothes
              .take(5)
              .map((c) => '${c.type} (${c.color}, ${c.occasion})')
              .join(', ');
          if (recentItems.isNotEmpty) {
            buffer.writeln('    Sample Items: $recentItems');
          }
        }
        buffer.writeln('');
      }

      return buffer.toString();
    } catch (e) {
      return 'Unable to load wardrobe context.';
    }
  }
}
