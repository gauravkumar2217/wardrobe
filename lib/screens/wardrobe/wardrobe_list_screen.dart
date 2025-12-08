import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/wardrobe_card.dart';
import '../../services/wardrobe_service.dart';
import '../../models/wardrobe.dart';
import 'create_wardrobe_screen.dart';

/// Wardrobe list screen
class WardrobeListScreen extends StatefulWidget {
  /// If true, shows only wardrobe labels for selection (no edit/delete)
  /// If false, shows full management options (edit/delete)
  final bool selectionMode;

  const WardrobeListScreen({
    super.key,
    this.selectionMode = false,
  });

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
        title: Text(widget.selectionMode ? 'Select Wardrobe' : 'My Wardrobes'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        actions: [
          // Only show add button when not in selection mode
          if (!widget.selectionMode)
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
                              // Set selected wardrobe
                              wardrobeProvider.setSelectedWardrobe(wardrobe);
                              
                              final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
                              
                              // Check if we're currently in the wardrobe tab (index 1) or if we were pushed
                              // If we're in the tab, switch to home tab
                              // If we were pushed (from filter icon), pop back to home
                              if (navigationProvider.currentIndex == 1) {
                                // We're in the wardrobe tab, switch to home tab
                                navigationProvider.navigateToHome();
                              } else {
                                // We were pushed (from filter icon or other screen), pop back
                                Navigator.of(context).pop();
                              }
                            },
                            // Only show edit/delete buttons if not in selection mode
                            onEdit: widget.selectionMode ? null : () {
                              _editWardrobe(wardrobe, authProvider.user!.uid);
                            },
                            onDelete: widget.selectionMode ? null : () {
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

  Future<void> _editWardrobe(Wardrobe wardrobe, String userId) async {
    await showDialog(
      context: context,
      builder: (context) => _EditWardrobeDialog(
        wardrobe: wardrobe,
        userId: userId,
        onSuccess: () {
          _loadWardrobes();
        },
      ),
    );
  }
}

/// Dialog widget for editing wardrobe
class _EditWardrobeDialog extends StatefulWidget {
  final Wardrobe wardrobe;
  final String userId;
  final VoidCallback onSuccess;

  const _EditWardrobeDialog({
    required this.wardrobe,
    required this.userId,
    required this.onSuccess,
  });

  @override
  State<_EditWardrobeDialog> createState() => _EditWardrobeDialogState();
}

class _EditWardrobeDialogState extends State<_EditWardrobeDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.wardrobe.name);
    _locationController = TextEditingController(text: widget.wardrobe.location);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveWardrobe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final wardrobeProvider = Provider.of<WardrobeProvider>(
        context,
        listen: false);

    try {
      await wardrobeProvider.updateWardrobe(
        userId: widget.userId,
        wardrobeId: widget.wardrobe.id,
        updates: {
          'name': _nameController.text.trim(),
          'location': _locationController.text.trim(),
        },
      );

      if (!mounted) return;

      if (wardrobeProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wardrobeProvider.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      } else {
        Navigator.pop(context);
        widget.onSuccess();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wardrobe updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update wardrobe: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Wardrobe'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Wardrobe Name *',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location *',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a location';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveWardrobe,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

