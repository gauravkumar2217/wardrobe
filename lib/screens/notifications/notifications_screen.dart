import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification.dart';
import '../../services/chat_service.dart';
import '../../services/cloth_service.dart';
import '../chat/chat_detail_screen.dart';
import '../cloth/cloth_detail_screen.dart';
import '../friends/friend_requests_screen.dart';

/// Notifications screen with grouped notifications and deep linking
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

    if (authProvider.user != null) {
      await notificationProvider.loadNotifications(authProvider.user!.uid);
      notificationProvider.watchNotifications(authProvider.user!.uid);
    }
  }

  Future<void> _handleNotificationTap(AppNotification notification) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

    if (authProvider.user == null) return;

    // Mark as read
    if (!notification.read) {
      await notificationProvider.markAsRead(
        userId: authProvider.user!.uid,
        notificationId: notification.id,
      );
    }

    // Deep link based on notification type
    if (!mounted) return;

    switch (notification.type) {
      case 'friend_request':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FriendRequestsScreen()),
        );
        break;

      case 'friend_accept':
        // Could navigate to friends list or friend's profile
        break;

      case 'dm_message':
        if (notification.chatId != null) {
          final chat = await ChatService.getChat(
            userId: authProvider.user!.uid,
            chatId: notification.chatId!,
          );
          if (chat != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)),
            );
          }
        }
        break;

      case 'cloth_like':
      case 'cloth_comment':
        if (notification.clothId != null && notification.userId != null) {
          // Get cloth details
          // Note: We need ownerId and wardrobeId from the notification data
          final ownerId = notification.data?['ownerId'] as String?;
          final wardrobeId = notification.data?['wardrobeId'] as String?;
          
          if (ownerId != null && wardrobeId != null) {
            final cloth = await ClothService.getCloth(
              userId: ownerId,
              wardrobeId: wardrobeId,
              clothId: notification.clothId!,
            );
            if (cloth != null && mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClothDetailScreen(
                    cloth: cloth,
                    isOwner: authProvider.user!.uid == ownerId,
                  ),
                ),
              );
            }
          }
        }
        break;

      case 'suggestion':
        // Navigate to home screen or specific suggestion
        break;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'friend_request':
        return Icons.person_add;
      case 'friend_accept':
        return Icons.check_circle;
      case 'dm_message':
        return Icons.chat;
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

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'friend_request':
        return Colors.blue;
      case 'friend_accept':
        return Colors.green;
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Map<String, List<AppNotification>> _groupNotifications(List<AppNotification> notifications) {
    final grouped = <String, List<AppNotification>>{};
    
    for (var notification in notifications) {
      final key = notification.type;
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(notification);
    }
    
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final groupedNotifications = _groupNotifications(notificationProvider.notifications);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        actions: [
          if (notificationProvider.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: () async {
                if (authProvider.user != null) {
                  await notificationProvider.markAllAsRead(authProvider.user!.uid);
                }
              },
            ),
        ],
      ),
      body: notificationProvider.isLoading && notificationProvider.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : notificationProvider.errorMessage != null && notificationProvider.notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          notificationProvider.errorMessage!,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          notificationProvider.clearError();
                          _loadNotifications();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : notificationProvider.notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No notifications',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'You\'re all caught up!',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: groupedNotifications.length,
                    itemBuilder: (context, index) {
                      final type = groupedNotifications.keys.elementAt(index);
                      final notifications = groupedNotifications[type]!;
                      final unreadCount = notifications.where((n) => !n.read).length;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ExpansionTile(
                          leading: Icon(
                            _getNotificationIcon(type),
                            color: _getNotificationColor(type),
                          ),
                          title: Text(
                            _getTypeTitle(type),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${notifications.length} notification${notifications.length == 1 ? '' : 's'}'),
                          trailing: unreadCount > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                          children: notifications.map((notification) {
                            return ListTile(
                              leading: notification.read
                                  ? null
                                  : Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                              title: Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(notification.body),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(notification.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () => _handleNotificationTap(notification),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () async {
                                  if (authProvider.user != null) {
                                    await notificationProvider.deleteNotification(
                                      userId: authProvider.user!.uid,
                                      notificationId: notification.id,
                                    );
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _getTypeTitle(String type) {
    switch (type) {
      case 'friend_request':
        return 'Friend Requests';
      case 'friend_accept':
        return 'Friend Accepts';
      case 'dm_message':
        return 'Messages';
      case 'cloth_like':
        return 'Likes';
      case 'cloth_comment':
        return 'Comments';
      case 'suggestion':
        return 'Suggestions';
      default:
        return 'Other';
    }
  }
}

