import 'package:flutter/material.dart';
import '../models/wardrobe.dart';

/// Wardrobe card widget
class WardrobeCard extends StatelessWidget {
  final Wardrobe wardrobe;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const WardrobeCard({
    super.key,
    required this.wardrobe,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          wardrobe.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(wardrobe.location),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${wardrobe.totalItems} items'),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

