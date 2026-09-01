import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../utils/shell_navigation.dart';
import '../screens/chat/chat_detail_screen.dart';
import '../screens/cloth/cloth_detail_screen.dart';
import '../screens/community/community_screen.dart';
import '../screens/events/events_planner_screen.dart';
import '../screens/suggestions/daily_suggestion_screen.dart';
import '../screens/suggestions/outfit_suggestion_screen.dart';
import '../utils/navigator_key.dart';
import 'chat_service.dart';
import 'cloth_service.dart';

/// Opens the correct screen from an FCM / local-notification payload.
class NotificationDeepLink {
  static String? _string(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final v = data[key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  static Future<void> open(Map<String, dynamic> data) async {
    final nav = navigatorKey.currentState;
    final context = navigatorKey.currentContext;
    if (nav == null || context == null) {
      if (kDebugMode) {
        debugPrint('NotificationDeepLink: navigator not ready');
      }
      return;
    }

    final type = _string(data, ['type']) ?? '';
    final screen = _string(data, ['screen']) ?? '';

    if (kDebugMode) {
      debugPrint('NotificationDeepLink: type=$type screen=$screen');
    }

    // Prefer explicit screen from Laravel payload; fall back to type.
    switch (screen) {
      case 'chat_detail':
        await _openChat(context, nav, data);
        return;
      case 'friend_requests':
        openShellOverlay(context, ShellRoutes.friendRequests);
        return;
      case 'friends':
        openShellOverlay(context, ShellRoutes.friendsList);
        return;
      case 'create_avatar':
        openShellOverlay(context, ShellRoutes.createAvatar);
        return;
      case 'settings':
        openShellOverlay(context, ShellRoutes.settings);
        return;
      case 'style_feed':
        _openCommunityTab(context);
        return;
      case 'style_comments':
        await _openClothOrCommunity(context, nav, data);
        return;
      case 'events_planner':
        await _openEvent(nav, data);
        return;
      case 'outfit_suggestion':
        nav.push(
          MaterialPageRoute(builder: (_) => const OutfitSuggestionScreen()),
        );
        return;
      case 'daily_suggestion':
        nav.push(
          MaterialPageRoute(builder: (_) => const DailySuggestionScreen()),
        );
        return;
    }

    switch (type) {
      case 'dm_message':
        await _openChat(context, nav, data);
        break;
      case 'friend_request':
        openShellOverlay(context, ShellRoutes.friendRequests);
        break;
      case 'friend_accept':
        openShellOverlay(context, ShellRoutes.friendsList);
        break;
      case 'avatar_ready':
      case 'avatar_failed':
        openShellOverlay(context, ShellRoutes.createAvatar);
        break;
      case 'cloth_like':
      case 'style_shared':
        _openCommunityTab(context);
        break;
      case 'cloth_comment':
        await _openClothOrCommunity(context, nav, data);
        break;
      case 'event_reminder':
        await _openEvent(nav, data);
        break;
      case 'outfit_suggestion':
        nav.push(
          MaterialPageRoute(builder: (_) => const OutfitSuggestionScreen()),
        );
        break;
      case 'daily_suggestion':
        nav.push(
          MaterialPageRoute(builder: (_) => const DailySuggestionScreen()),
        );
        break;
      case 'test_push':
        openShellOverlay(context, ShellRoutes.settings);
        break;
      default:
        if (kDebugMode) {
          debugPrint('NotificationDeepLink: no route for type=$type screen=$screen');
        }
    }
  }

  static void _openCommunityTab(BuildContext context) {
    try {
      Provider.of<NavigationProvider>(context, listen: false)
          .navigateToCommunity();
    } catch (_) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const CommunityScreen()),
      );
    }
  }

  static Future<void> _openChat(
    BuildContext context,
    NavigatorState nav,
    Map<String, dynamic> data,
  ) async {
    final chatId = _string(data, ['chat_id', 'chatId']);
    if (chatId == null) return;

    String? userId;
    try {
      userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    } catch (_) {}
    if (userId == null) return;

    final chat = await ChatService.getChat(userId: userId, chatId: chatId);
    if (chat == null) return;
    nav.push(MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)));
  }

  static Future<void> _openClothOrCommunity(
    BuildContext context,
    NavigatorState nav,
    Map<String, dynamic> data,
  ) async {
    final clothId = _string(data, ['cloth_id', 'clothId']);
    final ownerId = _string(data, ['owner_id', 'ownerId', 'from_user_id']);
    final wardrobeId = _string(data, ['wardrobe_id', 'wardrobeId']);

    if (clothId != null && ownerId != null && wardrobeId != null) {
      String? selfId;
      try {
        selfId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
      } catch (_) {}
      final cloth = await ClothService.getCloth(
        userId: ownerId,
        wardrobeId: wardrobeId,
        clothId: clothId,
      );
      if (cloth != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => ClothDetailScreen(
              cloth: cloth,
              isOwner: selfId == ownerId,
            ),
          ),
        );
        return;
      }
    }
    _openCommunityTab(context);
  }

  static Future<void> _openEvent(
    NavigatorState nav,
    Map<String, dynamic> data,
  ) async {
    final eventId = _string(data, ['event_id', 'eventId']);
    if (eventId != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(eventId: eventId),
        ),
      );
      return;
    }
    nav.push(MaterialPageRoute(builder: (_) => const EventsPlannerScreen()));
  }
}
