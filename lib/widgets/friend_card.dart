import 'package:flutter/material.dart';

/// Friend card widget
class FriendCard extends StatelessWidget {
  final String userId;
  final String? displayName;
  final String? photoUrl;
  final String? status; // 'friend', 'pending', 'requested'
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onRemove;

  const FriendCard({
    super.key,
    required this.userId,
    this.displayName,
    this.photoUrl,
    this.status,
    this.onTap,
    this.onAccept,
    this.onReject,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
          child: photoUrl == null
              ? Text(displayName?.substring(0, 1).toUpperCase() ?? 'U')
              : null,
        ),
        title: Text(displayName ?? 'Unknown User'),
        trailing: _buildTrailing(context),
        onTap: onTap,
      ),
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    if (status == 'pending' && onAccept != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: onAccept,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: onReject,
          ),
        ],
      );
    } else if (status == 'friend' && onRemove != null) {
      return IconButton(
        icon: const Icon(Icons.person_remove, color: Colors.red),
        onPressed: onRemove,
      );
    }
    return null;
  }
}

