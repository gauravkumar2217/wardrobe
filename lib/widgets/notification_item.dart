import 'package:flutter/material.dart';
import '../models/notification.dart';

/// Notification item widget
class NotificationItem extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;

  const NotificationItem({
    super.key,
    required this.notification,
    this.onTap,
  });

  IconData _getIcon() {
    switch (notification.type) {
      case 'friend_request':
        return Icons.person_add;
      case 'friend_accept':
        return Icons.person;
      case 'dm_message':
        return Icons.message;
      case 'cloth_like':
        return Icons.favorite;
      case 'cloth_comment':
        return Icons.comment;
      case 'suggestion':
        return Icons.lightbulb;
      default:
        return Icons.notifications;
    }
  }

  Color _getColor() {
    switch (notification.type) {
      case 'friend_request':
      case 'friend_accept':
        return Colors.blue;
      case 'dm_message':
        return Colors.purple;
      case 'cloth_like':
        return Colors.red;
      case 'cloth_comment':
        return Colors.orange;
      case 'suggestion':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getColor().withValues(alpha: 0.2),
        child: Icon(_getIcon(), color: _getColor()),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(notification.body),
      trailing: notification.read
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
      onTap: onTap,
    );
  }
}

