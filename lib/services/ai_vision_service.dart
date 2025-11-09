import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// AI Vision Service for image recognition and auto-tagging
/// Supports multiple providers: OpenAI Vision, Google Cloud Vision, etc.
class AIVisionService {
  // API Keys - can be configured via build config
  // For now, set to null (AI vision features will be disabled)
  static const String? _openaiApiKey = null;
  static const String? _googleVisionApiKey = null;

  /// Analyze image using OpenAI Vision API
  static Future<ClothMetadata> analyzeImageWithOpenAI(File imageFile) async {
    if (_openaiApiKey == null) {
      throw Exception('OpenAI API key not configured');
    }

    try {
      // Convert image to base64
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Call OpenAI Vision API
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openaiApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4-vision-preview',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': '''Analyze this clothing image and extract:
1. Clothing type (one of: Shirt, Pants, Dress, Jacket, Skirt, Shorts, Sweater, T-Shirt, Jeans, Blouse, Other)
2. Primary color (e.g., Blue, Red, Black, White)
3. Style/occasion (one of: Casual, Formal, Party, Work, Sports, Evening, Other)

Respond in JSON format:
{
  "type": "Shirt",
  "color": "Blue",
  "occasion": "Casual",
  "confidence": 0.85
}'''
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                }
              ]
            }
          ],
          'max_tokens': 300,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;

        // Parse JSON from response
        final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(content);
        if (jsonMatch != null) {
          final metadataJson = jsonDecode(jsonMatch.group(0)!);
          return ClothMetadata.fromJson(metadataJson);
        }
      }

      throw Exception('Failed to analyze image: ${response.statusCode}');
    } catch (e) {
      throw Exception('OpenAI Vision API error: $e');
    }
  }

  /// Analyze image using Google Cloud Vision API
  static Future<ClothMetadata> analyzeImageWithGoogleVision(
      File imageFile) async {
    if (_googleVisionApiKey == null) {
      throw Exception('Google Vision API key not configured');
    }

    try {
      // Convert image to base64
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Call Google Vision API
      final response = await http.post(
        Uri.parse(
          'https://vision.googleapis.com/v1/images:annotate?key=$_googleVisionApiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'LABEL_DETECTION', 'maxResults': 10},
                {'type': 'IMAGE_PROPERTIES', 'maxResults': 1},
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final labels = data['responses'][0]['labelAnnotations'] as List;
        final colors = data['responses'][0]['imagePropertiesAnnotation']
            ?['dominantColors']?['colors'] as List?;

        // Extract clothing type from labels
        String? type;
        for (final label in labels) {
          final description = (label['description'] as String).toLowerCase();
          if (description.contains('shirt') ||
              description.contains('t-shirt')) {
            type = 'T-Shirt';
            break;
          } else if (description.contains('pants') ||
              description.contains('trousers')) {
            type = 'Pants';
            break;
          } else if (description.contains('dress')) {
            type = 'Dress';
            break;
          } else if (description.contains('jacket')) {
            type = 'Jacket';
            break;
          } else if (description.contains('skirt')) {
            type = 'Skirt';
            break;
          } else if (description.contains('shorts')) {
            type = 'Shorts';
            break;
          } else if (description.contains('sweater')) {
            type = 'Sweater';
            break;
          } else if (description.contains('jeans')) {
            type = 'Jeans';
            break;
          } else if (description.contains('blouse')) {
            type = 'Blouse';
            break;
          }
        }
        type ??= 'Other';

        // Extract color from dominant colors
        String color = 'Unknown';
        if (colors != null && colors.isNotEmpty) {
          final dominantColor = colors[0]['color'];
          final r = dominantColor['red'] as int;
          final g = dominantColor['green'] as int;
          final b = dominantColor['blue'] as int;

          // Simple color mapping
          color = _rgbToColorName(r, g, b);
        }

        // Default occasion (can be improved with more analysis)
        const occasion = 'Casual';

        return ClothMetadata(
          type: type,
          color: color,
          occasion: occasion,
          confidence: 0.7,
        );
      }

      throw Exception('Failed to analyze image: ${response.statusCode}');
    } catch (e) {
      throw Exception('Google Vision API error: $e');
    }
  }

  /// Simple RGB to color name mapping
  static String _rgbToColorName(int r, int g, int b) {
    // Simple color detection logic
    if (r > 200 && g > 200 && b > 200) return 'White';
    if (r < 50 && g < 50 && b < 50) return 'Black';
    if (r > g && r > b) return 'Red';
    if (g > r && g > b) return 'Green';
    if (b > r && b > g) return 'Blue';
    if (r > 200 && g > 150 && b < 100) return 'Yellow';
    if (r > 150 && g < 100 && b > 150) return 'Purple';
    if (r > 200 && g > 100 && b < 100) return 'Orange';
    return 'Unknown';
  }

  /// Analyze image with fallback to multiple providers
  static Future<ClothMetadata> analyzeImage(File imageFile) async {
    // Try OpenAI first, fallback to Google Vision
    try {
      if (_openaiApiKey != null) {
        return await analyzeImageWithOpenAI(imageFile);
      }
    } catch (e) {
      // Fallback to Google Vision
    }

    if (_googleVisionApiKey != null) {
      return await analyzeImageWithGoogleVision(imageFile);
    }

    throw Exception('No AI vision service configured. Please set API keys.');
  }
}

/// Metadata extracted from image analysis
class ClothMetadata {
  final String type;
  final String color;
  final String occasion;
  final double confidence;

  ClothMetadata({
    required this.type,
    required this.color,
    required this.occasion,
    this.confidence = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'color': color,
      'occasion': occasion,
      'confidence': confidence,
    };
  }

  factory ClothMetadata.fromJson(Map<String, dynamic> json) {
    return ClothMetadata(
      type: json['type'] as String? ?? 'Other',
      color: json['color'] as String? ?? 'Unknown',
      occasion: json['occasion'] as String? ?? 'Casual',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
