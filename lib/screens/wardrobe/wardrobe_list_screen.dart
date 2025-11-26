import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/wardrobe_card.dart';
import 'create_wardrobe_screen.dart';
import '../home/home_screen.dart';

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
    _loadWardrobes();
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
          : wardrobeProvider.wardrobes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No wardrobes yet', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreateWardrobeScreen()),
                          ).then((_) => _loadWardrobes());
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create Wardrobe'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: wardrobeProvider.wardrobes.length,
                  itemBuilder: (context, index) {
                    final wardrobe = wardrobeProvider.wardrobes[index];
                    return WardrobeCard(
                      wardrobe: wardrobe,
                      onTap: () {
                        // Set selected wardrobe and navigate to home
                        wardrobeProvider.setSelectedWardrobe(wardrobe);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                        );
                      },
                      onDelete: () {
                        _deleteWardrobe(wardrobe.id, authProvider.user!.uid);
                      },
                    );
                  },
                ),
    );
  }

  Future<void> _deleteWardrobe(String wardrobeId, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Wardrobe'),
        content: const Text('Are you sure you want to delete this wardrobe? All clothes will be deleted.'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wardrobe deleted')),
        );
      }
    }
  }
}

