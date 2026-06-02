import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/outfit_suggestion.dart';
import '../../models/cloth.dart';
import '../../services/outfit_suggestion_service.dart';
import '../../services/cloth_service.dart';
import '../cloth/cloth_detail_screen.dart';

/// Screen showing outfit suggestions
class OutfitSuggestionScreen extends StatefulWidget {
  const OutfitSuggestionScreen({super.key});

  @override
  State<OutfitSuggestionScreen> createState() => _OutfitSuggestionScreenState();
}

class _OutfitSuggestionScreenState extends State<OutfitSuggestionScreen> {
  List<OutfitSuggestion> _suggestions = [];
  Map<String, List<Cloth>> _suggestionClothes =
      {}; // Map of suggestion ID to clothes
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        setState(() {
          _errorMessage = 'Please login to view suggestions';
          _isLoading = false;
        });
        return;
      }

      // Get last 3 suggestions
      final suggestions = await OutfitSuggestionService.getLastSuggestions(
        authProvider.user!.uid,
        count: 3,
      );

      // Load clothes for each suggestion
      final clothesMap = <String, List<Cloth>>{};
      for (final suggestion in suggestions) {
        final clothes = <Cloth>[];
        for (final clothId in suggestion.clothIds) {
          // Try to find the cloth - we need to search across all wardrobes
          final allClothes =
              await ClothService.getAllUserClothes(authProvider.user!.uid);
          final cloth = allClothes.firstWhere(
            (c) => c.id == clothId,
            orElse: () => throw Exception('Cloth not found'),
          );
          clothes.add(cloth);
        }
        clothesMap[suggestion.id] = clothes;
      }

      setState(() {
        _suggestions = suggestions;
        _suggestionClothes = clothesMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load suggestions: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outfit Suggestions'),
        backgroundColor: const Color(0xFF043915),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSuggestions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF043915),
                          foregroundColor: Colors.white,
                        ),
                        child:
                            const Text('Retry', style: TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                )
              : _suggestions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lightbulb_outline,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No suggestions yet',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Suggestions will appear here when you receive scheduled notifications',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        final clothes = _suggestionClothes[suggestion.id] ?? [];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Suggestion header
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.lightbulb,
                                          color: Color(0xFF043915),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            suggestion.title ??
                                                'Outfit Suggestion',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatDate(suggestion.createdAt),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (suggestion.description != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        suggestion.description!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              // Clothes grid
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: clothes.isEmpty
                                    ? const Text(
                                        'Clothes not found',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      )
                                    : GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 8,
                                          mainAxisSpacing: 8,
                                          childAspectRatio: 0.75,
                                        ),
                                        itemCount: clothes.length,
                                        itemBuilder: (context, clothIndex) {
                                          final cloth = clothes[clothIndex];
                                          return GestureDetector(
                                            onTap: () async {
                                              final authProvider =
                                                  Provider.of<AuthProvider>(
                                                context,
                                                listen: false,
                                              );
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ClothDetailScreen(
                                                    cloth: cloth,
                                                    isOwner: authProvider
                                                            .user?.uid ==
                                                        cloth.ownerId,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Card(
                                              elevation: 1,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          const BorderRadius
                                                              .vertical(
                                                        top: Radius.circular(4),
                                                      ),
                                                      child: Image.network(
                                                        cloth.imageUrl,
                                                        fit: BoxFit.cover,
                                                        width: double.infinity,
                                                        errorBuilder: (context,
                                                            error, stackTrace) {
                                                          return Container(
                                                            color: Colors
                                                                .grey[300],
                                                            child: const Icon(
                                                              Icons
                                                                  .image_not_supported,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          cloth.clothType,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        if (cloth.wornAt ==
                                                            null)
                                                          Text(
                                                            'Never worn',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors
                                                                  .orange[700],
                                                            ),
                                                          )
                                                        else
                                                          Text(
                                                            'Last worn: ${_formatDate(cloth.wornAt!)}',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors
                                                                  .grey[600],
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
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = difference.inDays ~/ 7;
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
