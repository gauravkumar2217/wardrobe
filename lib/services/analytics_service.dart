import 'package:firebase_analytics/firebase_analytics.dart';

/// Analytics service for tracking user events
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Log wardrobe created event
  static Future<void> logWardrobeCreated(String wardrobeId) async {
    await _analytics.logEvent(
      name: 'wardrobe_created',
      parameters: {'wardrobe_id': wardrobeId},
    );
  }

  /// Log cloth added event
  static Future<void> logClothAdded(String clothId, String type) async {
    await _analytics.logEvent(
      name: 'cloth_added',
      parameters: {
        'cloth_id': clothId,
        'cloth_type': type,
      },
    );
  }

  /// Log suggestion viewed event
  static Future<void> logSuggestionViewed(String suggestionId) async {
    await _analytics.logEvent(
      name: 'suggestion_viewed',
      parameters: {'suggestion_id': suggestionId},
    );
  }

  /// Log chat message sent event
  static Future<void> logChatMessageSent() async {
    await _analytics.logEvent(name: 'chat_message_sent');
  }

  /// Log outfit rated event
  static Future<void> logOutfitRated(String outfitId, int rating) async {
    await _analytics.logEvent(
      name: 'outfit_rated',
      parameters: {
        'outfit_id': outfitId,
        'rating': rating,
      },
    );
  }

  /// Log screen view
  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }
}

