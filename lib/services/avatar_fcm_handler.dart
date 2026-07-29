import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/avatar.dart';
import '../screens/profile/create_avatar_screen.dart';
import '../utils/navigator_key.dart';
import 'avatar_2d_service.dart';
import 'local_notification_service.dart';

/// Handles FCM messages related to avatar generation.
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
          _handleMessage(initial, fromTap: true);
        });
      });
    }
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    await _handleMessage(message, fromTap: false, showLocalIfNeeded: true);
  }

  static Future<void> _onMessageOpened(RemoteMessage message) async {
    await _handleMessage(message, fromTap: true);
  }

  static bool _isAvatarMessage(RemoteMessage message) {
    final type = message.data['type']?.toString();
    return type == 'avatar_ready' || type == 'avatar_failed';
  }

  static Future<void> _handleMessage(
    RemoteMessage message, {
    required bool fromTap,
    bool showLocalIfNeeded = false,
  }) async {
    if (!_isAvatarMessage(message)) return;

    final type = message.data['type']?.toString() ?? '';
    final avatarId = message.data['avatar_id']?.toString();
    final status = message.data['generation_status']?.toString() ??
        (type == 'avatar_ready' ? 'completed' : 'failed');

    if (kDebugMode) {
      debugPrint('Avatar FCM received: type=$type avatarId=$avatarId');
    }

    await Avatar2DService.clearPendingAvatarId();
    Avatar2DService.stopBackgroundPolling();

    if (avatarId != null && avatarId.isNotEmpty) {
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

    if (showLocalIfNeeded) {
      final title = message.notification?.title ??
          (type == 'avatar_ready'
              ? 'Your avatar is ready'
              : 'Avatar creation failed');
      final body = message.notification?.body ??
          (type == 'avatar_ready'
              ? 'Open the app to use your avatar.'
              : 'Tap to retry avatar creation.');
      await LocalNotificationService.sendImmediateNotification(
        title: title,
        body: body,
        payload: jsonEncode({
          'type': type,
          'avatar_id': avatarId,
          'screen': 'create_avatar',
        }),
      );
    }

    if (fromTap) {
      openCreateAvatarScreen();
    }
  }

  static void openCreateAvatarScreen() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute<void>(builder: (_) => const CreateAvatarScreen()),
    );
  }
}
