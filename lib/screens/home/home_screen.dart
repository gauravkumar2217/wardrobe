import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cloth_provider.dart';
import '../../widgets/cloth_card.dart';

/// Home screen with swipeable fullscreen cloth cards
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadClothes();
  }

  void _loadClothes() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      clothProvider.loadClothes(userId: authProvider.user!.uid);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final clothProvider = Provider.of<ClothProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wardrobe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Navigate to notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // Navigate to profile
            },
          ),
        ],
      ),
      body: clothProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : clothProvider.clothes.isEmpty
              ? const Center(child: Text('No clothes found'))
              : PageView.builder(
                  controller: _pageController,
                  itemCount: clothProvider.clothes.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final cloth = clothProvider.clothes[index];
                    final isOwner = authProvider.user?.uid == cloth.ownerId;
                    
                    return ClothCard(
                      cloth: cloth,
                      isOwner: isOwner,
                      isLiked: false, // TODO: Check like status
                      onLike: () {
                        // TODO: Handle like
                      },
                      onComment: () {
                        // TODO: Handle comment
                      },
                      onShare: () {
                        // TODO: Handle share
                      },
                      onMarkWorn: () {
                        if (isOwner) {
                          clothProvider.markAsWornToday(
                            userId: authProvider.user!.uid,
                            wardrobeId: cloth.wardrobeId,
                            clothId: cloth.id,
                          );
                        }
                      },
                      onEdit: isOwner
                          ? () {
                              // TODO: Navigate to edit screen
                            }
                          : null,
                    );
                  },
                ),
    );
  }
}

