import 'package:flutter/foundation.dart';

/// Admin moderation — handled by Laravel admin panel; no client Firestore.
class ModerationService {
  static Future<void> removeContent({
    required String moderatorId,
    required String targetUserId,
    required String targetContentId,
    required String contentType,
    required String reason,
  }) async {
    debugPrint(
      'ModerationService.removeContent is server-side only ($contentType)',
    );
  }

  static Future<void> ejectUser({
    required String moderatorId,
    required String targetUserId,
    required String reason,
  }) async {
    debugPrint('ModerationService.ejectUser is server-side only');
  }

  static Future<void> warnUser({
    required String moderatorId,
    required String targetUserId,
    required String reason,
  }) async {
    debugPrint('ModerationService.warnUser is server-side only');
  }

  static Future<List<Map<String, dynamic>>> getModerationActionsForUser(
    String userId,
  ) async {
    return [];
  }
}

enum ModerationActionType {
  removeContent,
  ejectUser,
  warnUser;

  @override
  String toString() {
    switch (this) {
      case ModerationActionType.removeContent:
        return 'remove_content';
      case ModerationActionType.ejectUser:
        return 'eject_user';
      case ModerationActionType.warnUser:
        return 'warn_user';
    }
  }
}
