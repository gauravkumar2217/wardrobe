import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/wardrobe_card.dart';
import '../../services/wardrobe_service.dart';
import 'create_wardrobe_screen.dart';

/// Wardrobe list screen
class WardrobeListScreen extends StatefulWidget {
  const WardrobeListScreen({super.key});

  @override
  State<WardrobeListScreen> createState() => _WardrobeListScreenState();
}

class _WardrobeListScreenState extends State<WardrobeListScreen> {
  @override
  void initState() {
    super.initState();
    // Defer loading until after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWardrobes();
    });
  }

  void _loadWardrobes() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final wardrobeProvider = Provider.of<WardrobeProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      wardrobeProvider.loadWardrobes(authProvider.user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final wardrobeProvider = Provider.of<WardrobeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wardrobes'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateWardrobeScreen()),
              ).then((_) => _loadWardrobes());
            },
          ),
        ],
      ),
      body: wardrobeProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : wardrobeProvider.errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          wardrobeProvider.errorMessage!,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          wardrobeProvider.clearError();
                          _loadWardrobes();
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
              : wardrobeProvider.wardrobes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No wardrobes yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create your first wardrobe to organize your clothes!',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CreateWardrobeScreen()),
                              ).then((_) => _loadWardrobes());
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create Wardrobe'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        _loadWardrobes();
                        await Future.delayed(const Duration(milliseconds: 500));
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: wardrobeProvider.wardrobes.length,
                        itemBuilder: (context, index) {
                          final wardrobe = wardrobeProvider.wardrobes[index];
                          return WardrobeCard(
                            wardrobe: wardrobe,
                            onTap: () {
                              // Set selected wardrobe and navigate to home
                              wardrobeProvider.setSelectedWardrobe(wardrobe);
                              // Switch to Home tab in main navigation
                              final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
                              navigationProvider.navigateToHome();
                            },
                            onDelete: () {
                              _deleteWardrobe(wardrobe.id, authProvider.user!.uid);
                            },
                          );
                        },
                      ),
                    ),
    );
  }

  Future<void> _deleteWardrobe(String wardrobeId, String userId) async {
    // Check if wardrobe has clothes
    try {
      final clothesCount = await WardrobeService.getClothesCount(
        userId: userId,
        wardrobeId: wardrobeId,
      );

      if (clothesCount > 0) {
        // Show warning dialog if wardrobe has clothes
        if (!context.mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cannot Delete Wardrobe'),
            content: Text(
              'This wardrobe contains $clothesCount item(s).\n\n'
              'You need to arrange your clothes in the right place before removing the wardrobe.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      // If check fails, show error and return
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to check wardrobe: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // If no clothes, show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Wardrobe'),
        content: const Text('Are you sure you want to delete this wardrobe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final wardrobeProvider = Provider.of<WardrobeProvider>(context, listen: false);
      await wardrobeProvider.deleteWardrobe(userId: userId, wardrobeId: wardrobeId);
      if (!context.mounted) return;
      if (wardrobeProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wardrobeProvider.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wardrobe deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

