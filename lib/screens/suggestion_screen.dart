import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/wardrobe.dart';
import '../models/cloth.dart';
import '../providers/suggestion_provider.dart';
import '../providers/cloth_provider.dart';
import '../providers/wardrobe_provider.dart';
import '../services/cloth_service.dart';
import '../services/notification_service.dart';
import '../widgets/suggestion_card.dart';
import 'wardrobe_detail_screen.dart';

class SuggestionScreen extends StatefulWidget {
  const SuggestionScreen({super.key});

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen> {
  String? _selectedOccasion;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final suggestionProvider = context.read<SuggestionProvider>();
      suggestionProvider.loadTodaySuggestion(user.uid);
      suggestionProvider.loadHistory(user.uid);
    }
  }

  Future<void> _generateSuggestion(
    String userId,
    Wardrobe wardrobe,
  ) async {
    final suggestionProvider = context.read<SuggestionProvider>();
    final result = await suggestionProvider.generateSuggestion(
      userId,
      wardrobe.id,
      wardrobe,
      occasion: _selectedOccasion,
    );

    if (mounted && result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suggestion generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted && suggestionProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(suggestionProvider.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markAllAsWorn(
    String userId,
    String wardrobeId,
    List<String> clothIds,
  ) async {
    final clothProvider = context.read<ClothProvider>();
    
    for (final clothId in clothIds) {
      await clothProvider.markAsWorn(userId, wardrobeId, clothId);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All items marked as worn!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login')),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Outfit Suggestions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Consumer<WardrobeProvider>(
                    builder: (context, wardrobeProvider, child) {
                      if (wardrobeProvider.wardrobes.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No wardrobes yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create a wardrobe to get suggestions',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Consumer<SuggestionProvider>(
                        builder: (context, suggestionProvider, child) {
                          return RefreshIndicator(
                            onRefresh: () async {
                              await suggestionProvider.loadTodaySuggestion(user.uid);
                              await suggestionProvider.loadHistory(user.uid);
                            },
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Occasion Filter
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedOccasion,
                                    decoration: InputDecoration(
                                      labelText: 'Filter by Occasion (Optional)',
                                      prefixIcon: const Icon(Icons.filter_list),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: null,
                                        child: Text('All Occasions'),
                                      ),
                                      ...Cloth.occasionOptions.map((occasion) {
                                        return DropdownMenuItem(
                                          value: occasion,
                                          child: Text(occasion),
                                        );
                                      }),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedOccasion = value;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 24),

                                  // Generate Button
                                  ElevatedButton.icon(
                                    onPressed: suggestionProvider.isLoading
                                        ? null
                                        : () async {
                                            final wardrobe = wardrobeProvider.wardrobes.first;
                                            await _generateSuggestion(user.uid, wardrobe);
                                          },
                                    icon: suggestionProvider.isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : const Icon(Icons.auto_awesome),
                                    label: Text(
                                      suggestionProvider.isLoading
                                          ? 'Generating...'
                                          : 'Get New Suggestion',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7C3AED),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Test Notification Button (for testing)
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      try {
                                        await NotificationService.showNotification(
                                          title: 'Wardrobe',
                                          body: 'Outfit Suggestion Ready! Check out today\'s outfit suggestion',
                                        );
                                        if (!mounted) return;
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('Test notification sent!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to send notification: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.notifications_active),
                                    label: const Text('Test Notification'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF7C3AED),
                                      side: const BorderSide(color: Color(0xFF7C3AED)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Today's Suggestion
                                  if (suggestionProvider.todaySuggestion != null) ...[
                                    FutureBuilder<List<Cloth>>(
                                      future: ClothService.getClothes(
                                        user.uid,
                                        suggestionProvider.todaySuggestion!.wardrobeId,
                                      ),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        }

                                        if (snapshot.hasError || !snapshot.hasData) {
                                          return const SizedBox.shrink();
                                        }

                                        final wardrobe = wardrobeProvider.wardrobes.firstWhere(
                                          (w) => w.id ==
                                              suggestionProvider.todaySuggestion!.wardrobeId,
                                          orElse: () => wardrobeProvider.wardrobes.first,
                                        );

                                        return SuggestionCard(
                                          suggestion: suggestionProvider.todaySuggestion!,
                                          clothes: snapshot.data!,
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => WardrobeDetailScreen(
                                                  wardrobe: wardrobe,
                                                ),
                                              ),
                                            );
                                          },
                                          onMarkAsWorn: () async {
                                            await _markAllAsWorn(
                                              user.uid,
                                              suggestionProvider.todaySuggestion!.wardrobeId,
                                              suggestionProvider.todaySuggestion!.clothIds,
                                            );
                                            await suggestionProvider.markAsViewed(
                                              user.uid,
                                              suggestionProvider.todaySuggestion!.id,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                  ],

                                  // History Section
                                  if (suggestionProvider.history.isNotEmpty) ...[
                                    const Text(
                                      'Recent Suggestions',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ...suggestionProvider.history.map((suggestion) {
                                      return FutureBuilder<List<Cloth>>(
                                        future: ClothService.getClothes(
                                          user.uid,
                                          suggestion.wardrobeId,
                                        ),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) {
                                            return const SizedBox.shrink();
                                          }

                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: SuggestionCard(
                                              suggestion: suggestion,
                                              clothes: snapshot.data!,
                                            ),
                                          );
                                        },
                                      );
                                    }),
                                  ],

                                  // Empty State
                                  if (suggestionProvider.todaySuggestion == null &&
                                      suggestionProvider.history.isEmpty &&
                                      !suggestionProvider.isLoading)
                                    Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.lightbulb_outline,
                                            size: 80,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No suggestions yet',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Tap "Get New Suggestion" to generate one',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

