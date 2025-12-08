import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cloth_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../models/wardrobe.dart';

/// Statistics screen showing counts by type, occasion, season, and color
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, int> _typeCounts = {};
  Map<String, int> _occasionCounts = {};
  Map<String, int> _seasonCounts = {};
  Map<String, int> _colorCounts = {};
  List<Wardrobe> _wardrobes = [];
  bool _isLoadingWardrobes = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateStatistics();
      _loadWardrobes();
    });
  }

  Future<void> _loadWardrobes() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    setState(() {
      _isLoadingWardrobes = true;
    });

    try {
      final wardrobeProvider = Provider.of<WardrobeProvider>(context, listen: false);
      await wardrobeProvider.loadWardrobes(authProvider.user!.uid);
      
      setState(() {
        _wardrobes = wardrobeProvider.wardrobes;
        _isLoadingWardrobes = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingWardrobes = false;
      });
    }
  }

  void _calculateStatistics() {
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);
    final clothes = clothProvider.clothes;

    final typeCounts = <String, int>{};
    final occasionCounts = <String, int>{};
    final seasonCounts = <String, int>{};
    final colorCounts = <String, int>{};

    for (var cloth in clothes) {
      // Count by type
      typeCounts[cloth.clothType] = (typeCounts[cloth.clothType] ?? 0) + 1;

      // Count by occasions
      for (var occasion in cloth.occasions) {
        occasionCounts[occasion] = (occasionCounts[occasion] ?? 0) + 1;
      }

      // Count by season
      seasonCounts[cloth.season] = (seasonCounts[cloth.season] ?? 0) + 1;

      // Count by colors
      for (var color in cloth.colorTags.colors) {
        colorCounts[color] = (colorCounts[color] ?? 0) + 1;
      }
    }

    setState(() {
      _typeCounts = typeCounts;
      _occasionCounts = occasionCounts;
      _seasonCounts = seasonCounts;
      _colorCounts = colorCounts;
    });
  }

  void _navigateToHomeWithFilter({
    String? type,
    String? occasion,
    String? season,
    String? color,
  }) {
    // Set filter in provider
    final filterProvider = Provider.of<FilterProvider>(context, listen: false);
    filterProvider.setFilter(
      type: type,
      occasion: occasion,
      season: season,
      color: color,
    );
    
    // Navigate to home screen
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    navigationProvider.navigateToHome();
    
    // Pop statistics screen
    Navigator.pop(context);
  }

  void _navigateToHomeWithWardrobe(Wardrobe wardrobe) {
    // Set selected wardrobe in provider
    final wardrobeProvider = Provider.of<WardrobeProvider>(context, listen: false);
    wardrobeProvider.setSelectedWardrobe(wardrobe);
    
    // Clear any filters
    final filterProvider = Provider.of<FilterProvider>(context, listen: false);
    filterProvider.clearFilters();
    
    // Navigate to home screen
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    navigationProvider.navigateToHome();
    
    // Pop statistics screen
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final clothProvider = Provider.of<ClothProvider>(context, listen: false);
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          if (authProvider.user != null) {
            await clothProvider.loadClothes(userId: authProvider.user!.uid);
            _calculateStatistics();
            await _loadWardrobes();
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // My Wardrobes Section
              _buildWardrobesSection(),
              const SizedBox(height: 16),
              // Type Statistics
              _buildSection(
                title: 'By Type',
                icon: Icons.checkroom,
                counts: _typeCounts,
                onTap: (type) => _navigateToHomeWithFilter(type: type),
              ),
              const SizedBox(height: 16),
              // Occasion Statistics
              _buildSection(
                title: 'By Occasion',
                icon: Icons.event,
                counts: _occasionCounts,
                onTap: (occasion) => _navigateToHomeWithFilter(occasion: occasion),
              ),
              const SizedBox(height: 16),
              // Season Statistics
              _buildSection(
                title: 'By Season',
                icon: Icons.wb_sunny,
                counts: _seasonCounts,
                onTap: (season) => _navigateToHomeWithFilter(season: season),
              ),
              const SizedBox(height: 16),
              // Color Statistics
              _buildSection(
                title: 'By Color',
                icon: Icons.palette,
                counts: _colorCounts,
                onTap: (color) => _navigateToHomeWithFilter(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Map<String, int> counts,
    required Function(String) onTap,
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
              return ListTile(
                title: Text(entry.key),
                trailing: Chip(
                  label: Text('${entry.value}'),
                  backgroundColor: const Color(0xFF7C3AED).withOpacity(0.1),
                  labelStyle: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () => onTap(entry.key),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildWardrobesSection() {
    if (_isLoadingWardrobes) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.inventory_2, color: Colors.grey),
              const SizedBox(width: 12),
              const Text(
                'Loading wardrobes...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_wardrobes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.inventory_2, color: Colors.grey),
              const SizedBox(width: 12),
              Text(
                'No wardrobes available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Sort by count (descending)
    final sortedWardrobes = List<Wardrobe>.from(_wardrobes)
      ..sort((a, b) => b.totalItems.compareTo(a.totalItems));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                const Text(
                  'My Wardrobes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedWardrobes.map((wardrobe) {
              return ListTile(
                title: Text(wardrobe.name),
                subtitle: wardrobe.location.isNotEmpty
                    ? Text(wardrobe.location)
                    : null,
                trailing: Chip(
                  label: Text('${wardrobe.totalItems}'),
                  backgroundColor: const Color(0xFF7C3AED).withOpacity(0.1),
                  labelStyle: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () => _navigateToHomeWithWardrobe(wardrobe),
              );
            }),
          ],
        ),
      ),
    );
  }
}

