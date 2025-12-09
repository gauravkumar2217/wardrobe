import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cloth_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../models/wardrobe.dart';

/// Filter selection screen with multi-select options
class FilterSelectionScreen extends StatefulWidget {
  const FilterSelectionScreen({super.key});

  @override
  State<FilterSelectionScreen> createState() => _FilterSelectionScreenState();
}

class _FilterSelectionScreenState extends State<FilterSelectionScreen> {
  // Selected filters
  Set<String> _selectedTypes = {};
  Set<String> _selectedOccasions = {};
  Set<String> _selectedSeasons = {};
  Set<String> _selectedColors = {};
  String? _selectedWardrobeId;

  // Available options
  Map<String, int> _typeCounts = {};
  Map<String, int> _occasionCounts = {};
  Map<String, int> _seasonCounts = {};
  Map<String, int> _colorCounts = {};
  List<Wardrobe> _wardrobes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final clothProvider = Provider.of<ClothProvider>(context, listen: false);
      final wardrobeProvider = Provider.of<WardrobeProvider>(context, listen: false);
      final filterProvider = Provider.of<FilterProvider>(context, listen: false);

      if (authProvider.user != null) {
        // Load clothes to calculate statistics
        await clothProvider.loadClothes(userId: authProvider.user!.uid);
        final clothes = clothProvider.clothes;

        // Calculate counts
        final typeCounts = <String, int>{};
        final occasionCounts = <String, int>{};
        final seasonCounts = <String, int>{};
        final colorCounts = <String, int>{};

        for (var cloth in clothes) {
          typeCounts[cloth.clothType] = (typeCounts[cloth.clothType] ?? 0) + 1;
          for (var occasion in cloth.occasions) {
            occasionCounts[occasion] = (occasionCounts[occasion] ?? 0) + 1;
          }
          seasonCounts[cloth.season] = (seasonCounts[cloth.season] ?? 0) + 1;
          for (var color in cloth.colorTags.colors) {
            colorCounts[color] = (colorCounts[color] ?? 0) + 1;
          }
        }

        // Load wardrobes
        await wardrobeProvider.loadWardrobes(authProvider.user!.uid);

        // Load current filter selections
        _selectedTypes = filterProvider.filterTypes.toSet();
        _selectedOccasions = filterProvider.filterOccasions.toSet();
        _selectedSeasons = filterProvider.filterSeasons.toSet();
        _selectedColors = filterProvider.filterColors.toSet();
        _selectedWardrobeId = filterProvider.selectedWardrobeId;

        setState(() {
          _typeCounts = typeCounts;
          _occasionCounts = occasionCounts;
          _seasonCounts = seasonCounts;
          _colorCounts = colorCounts;
          _wardrobes = wardrobeProvider.wardrobes;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final filterProvider = Provider.of<FilterProvider>(context, listen: false);
    final wardrobeProvider = Provider.of<WardrobeProvider>(context, listen: false);

    // Set selected wardrobe if any
    if (_selectedWardrobeId != null) {
      final wardrobe = _wardrobes.firstWhere(
        (w) => w.id == _selectedWardrobeId,
        orElse: () => wardrobeProvider.wardrobes.firstWhere(
          (w) => w.id == _selectedWardrobeId,
        ),
      );
      wardrobeProvider.setSelectedWardrobe(wardrobe);
    } else {
      wardrobeProvider.setSelectedWardrobe(null);
    }

    // Apply multiple filters
    filterProvider.setMultipleFilters(
      types: _selectedTypes.toList(),
      occasions: _selectedOccasions.toList(),
      seasons: _selectedSeasons.toList(),
      colors: _selectedColors.toList(),
      wardrobeId: _selectedWardrobeId,
    );

    Navigator.pop(context);
  }

  void _clearAllFilters() {
    setState(() {
      _selectedTypes.clear();
      _selectedOccasions.clear();
      _selectedSeasons.clear();
      _selectedColors.clear();
      _selectedWardrobeId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Clothes'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        actions: [
          if (_hasSelections())
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text(
                'Clear All',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Wardrobes Section
                        _buildWardrobesSection(),
                        const SizedBox(height: 16),
                        // Type Section
                        _buildSection(
                          title: 'By Type',
                          icon: Icons.checkroom,
                          counts: _typeCounts,
                          selected: _selectedTypes,
                          onToggle: (value) {
                            setState(() {
                              if (_selectedTypes.contains(value)) {
                                _selectedTypes.remove(value);
                              } else {
                                _selectedTypes.add(value);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        // Occasion Section
                        _buildSection(
                          title: 'By Occasion',
                          icon: Icons.event,
                          counts: _occasionCounts,
                          selected: _selectedOccasions,
                          onToggle: (value) {
                            setState(() {
                              if (_selectedOccasions.contains(value)) {
                                _selectedOccasions.remove(value);
                              } else {
                                _selectedOccasions.add(value);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        // Season Section
                        _buildSection(
                          title: 'By Season',
                          icon: Icons.wb_sunny,
                          counts: _seasonCounts,
                          selected: _selectedSeasons,
                          onToggle: (value) {
                            setState(() {
                              if (_selectedSeasons.contains(value)) {
                                _selectedSeasons.remove(value);
                              } else {
                                _selectedSeasons.add(value);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        // Color Section
                        _buildSection(
                          title: 'By Color',
                          icon: Icons.palette,
                          counts: _colorCounts,
                          selected: _selectedColors,
                          onToggle: (value) {
                            setState(() {
                              if (_selectedColors.contains(value)) {
                                _selectedColors.remove(value);
                              } else {
                                _selectedColors.add(value);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Apply Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _applyFilters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          _hasSelections()
                              ? 'Apply Filters (${_getTotalSelections()})'
                              : 'Apply Filters',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  bool _hasSelections() {
    return _selectedTypes.isNotEmpty ||
        _selectedOccasions.isNotEmpty ||
        _selectedSeasons.isNotEmpty ||
        _selectedColors.isNotEmpty ||
        _selectedWardrobeId != null;
  }

  int _getTotalSelections() {
    return _selectedTypes.length +
        _selectedOccasions.length +
        _selectedSeasons.length +
        _selectedColors.length +
        (_selectedWardrobeId != null ? 1 : 0);
  }

  Widget _buildWardrobesSection() {
    if (_wardrobes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2, color: Color(0xFF7C3AED)),
                SizedBox(width: 8),
                Text(
                  'My Wardrobes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._wardrobes.map((wardrobe) {
              final isSelected = _selectedWardrobeId == wardrobe.id;
              return CheckboxListTile(
                title: Text(wardrobe.name),
                subtitle: wardrobe.location.isNotEmpty
                    ? Text(wardrobe.location)
                    : null,
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    _selectedWardrobeId = value == true ? wardrobe.id : null;
                  });
                },
                activeColor: const Color(0xFF7C3AED),
                secondary: Chip(
                  label: Text('${wardrobe.totalItems}'),
                  backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  labelStyle: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Map<String, int> counts,
    required Set<String> selected,
    required Function(String) onToggle,
  }) {
    if (counts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey),
              const SizedBox(width: 12),
              Text(
                'No $title data available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Sort by count (descending)
    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedEntries.map((entry) {
              final isSelected = selected.contains(entry.key);
              return CheckboxListTile(
                title: Text(entry.key),
                value: isSelected,
                onChanged: (value) => onToggle(entry.key),
                activeColor: const Color(0xFF7C3AED),
                secondary: Chip(
                  label: Text('${entry.value}'),
                  backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  labelStyle: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

