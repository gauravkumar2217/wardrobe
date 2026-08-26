import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/notification_provider.dart';
import '../utils/navigator_key.dart';
import 'avatar_2d_service.dart';
import 'local_notification_service.dart';
import 'notification_deep_link.dart';

/// Central FCM inbound handler: foreground local notifications + deep links.
///
/// Chat (`dm_message` / `chat_detail`) is suppressed only while that chat is
/// open. All other types always show a tray notification with a screen link.
class AvatarFcmHandler {
  static bool _wired = false;

  static Future<void> initialize() async {
    if (_wired) return;
    _wired = true;

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 600), () {
          _onMessageOpened(initial);
        });
      });
    }
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    if (_isAvatarMessage(message)) {
      await _applyAvatarSideEffects(message);
    }

    if (_shouldSuppressChatNotification(message)) {
      if (kDebugMode) {
        debugPrint(
          'FCM suppressed (active chat): chat_id=${message.data['chat_id']}',
        );
      }
      await _refreshInAppNotifications();
      return;
    }

    await _showForegroundLocalNotification(message);
    await _refreshInAppNotifications();
  }

  static Future<void> _onMessageOpened(RemoteMessage message) async {
    if (_isAvatarMessage(message)) {
      await _applyAvatarSideEffects(message);
    }
    await NotificationDeepLink.open(_payloadMap(message));
  }

  static bool _isAvatarMessage(RemoteMessage message) {
    final type = message.data['type']?.toString();
    return type == 'avatar_ready' || type == 'avatar_failed';
  }

  static bool _isChatMessage(RemoteMessage message) {
    final type = message.data['type']?.toString();
    final screen = message.data['screen']?.toString();
    return type == 'dm_message' || screen == 'chat_detail';
  }

  /// Suppress tray only when this chat thread is currently open.
  static bool _shouldSuppressChatNotification(RemoteMessage message) {
    if (!_isChatMessage(message)) return false;

    final chatId = (message.data['chat_id'] ?? message.data['chatId'])
        ?.toString()
        .trim();
    if (chatId == null || chatId.isEmpty) return false;

    final context = navigatorKey.currentContext;
    if (context == null) return false;

    try {
      final active = Provider.of<ChatProvider>(context, listen: false)
          .activeChatId;
      return active != null && active == chatId;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _payloadMap(RemoteMessage message) {
    return <String, dynamic>{
      ...message.data,
      if (message.notification?.title != null)
        'title': message.notification!.title,
      if (message.notification?.body != null)
        'body': message.notification!.body,
    };
  }

  static Future<void> _showForegroundLocalNotification(
    RemoteMessage message,
  ) async {
    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'Wardrobe';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        '';
    if (body.isEmpty && message.notification == null) {
      if (kDebugMode) {
        debugPrint(
          'FCM foreground ignored (no body): ${message.messageId} '
          'data=${message.data}',
        );
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
        'FCM foreground → local notification: '
        'title=$title type=${message.data['type']} '
        'screen=${message.data['screen']}',
      );
    }

    await LocalNotificationService.sendImmediateNotification(
      title: title,
      body: body.isEmpty ? 'New notification' : body,
      payload: jsonEncode(_payloadMap(message)),
    );
  }

  static Future<void> _refreshInAppNotifications() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    try {
      final userId =
          Provider.of<AuthProvider>(context, listen: false).user?.uid;
      if (userId == null) return;
      await Provider.of<NotificationProvider>(context, listen: false)
          .loadNotifications(userId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM in-app notification refresh failed: $e');
      }
    }
  }

  static Future<void> _applyAvatarSideEffects(RemoteMessage message) async {
    final type = message.data['type']?.toString() ?? '';
    final avatarId = message.data['avatar_id']?.toString();
    final status = message.data['generation_status']?.toString() ??
        (type == 'avatar_ready' ? 'completed' : 'failed');

    if (kDebugMode) {
      debugPrint('Avatar FCM received: type=$type avatarId=$avatarId');
    }

    await Avatar2DService.clearPendingAvatarId();
    Avatar2DService.stopBackgroundPolling();

    if (avatarId == null || avatarId.isEmpty) return;

    try {
      final statusPayload = await Avatar2DService.getAvatarStatus(avatarId);
      final s = statusPayload['generation_status']?.toString() ?? status;
      Avatar2DService.notifyExternalStatus(
        Avatar(
          userId: 'self',
          generationStatus: s,
          generationJobId: avatarId,
          avatarImageUrl: statusPayload['avatar_image_url']?.toString(),
          avatarPreviewUrl: statusPayload['avatar_preview_url']?.toString(),
          errorMessage: statusPayload['error_message']?.toString(),
        ),
      );
    } catch (e) {
      debugPrint('Avatar FCM status refresh failed: $e');
      Avatar2DService.notifyExternalStatus(
        Avatar(
          userId: 'self',
          generationStatus: status,
          generationJobId: avatarId,
        ),
      );
    }
  }
}
