import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/wardrobe_card.dart';
import '../../widgets/banner_slider_widget.dart';
import '../../services/wardrobe_service.dart';
import '../../services/banner_service.dart';
import '../../models/wardrobe.dart';
import '../../models/banner.dart' as models;
import 'create_wardrobe_screen.dart';
import '../../theme/wardrobe_tokens.dart';
import 'wardrobe_assets_screen.dart';

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
  final BannerService _bannerService = BannerService();
  List<models.Banner> _banners = [];
  Wardrobe? _viewingWardrobe;

  @override
  void initState() {
    super.initState();
    // Defer loading until after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWardrobes();
      _loadBanners();
    });
  }

  Future<void> _loadBanners() async {
    try {
      final banners = await _bannerService.getBannersByLocation('wardrobe_list');
      if (mounted) {
        setState(() {
          _banners = banners;
        });
      }
    } catch (e) {
      // Silently handle errors - banners are optional
    }
  }

  void _loadWardrobes() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final wardrobeProvider = Provider.of<WardrobeProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      wardrobeProvider.loadWardrobes(authProvider.user!.uid);
    }
  }

  void _openWardrobeAssets(Wardrobe wardrobe) {
    final wardrobeProvider =
        Provider.of<WardrobeProvider>(context, listen: false);
    wardrobeProvider.setSelectedWardrobe(wardrobe);
    setState(() => _viewingWardrobe = wardrobe);
  }

  void _closeWardrobeAssets() {
    setState(() => _viewingWardrobe = null);
    _loadWardrobes();
  }

  @override
  Widget build(BuildContext context) {
    if (_viewingWardrobe != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _closeWardrobeAssets();
        },
        child: WardrobeAssetsScreen(
          wardrobe: _viewingWardrobe!,
          onClose: _closeWardrobeAssets,
        ),
      );
    }

    final authProvider = Provider.of<AuthProvider>(context);
    final wardrobeProvider = Provider.of<WardrobeProvider>(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: wardrobeProvider.isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading wardrobes...',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : wardrobeProvider.errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: scheme.secondary,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          wardrobeProvider.errorMessage!,
                          style: TextStyle(
                            fontSize: 14,
                            color: scheme.onSurface.withValues(alpha: 0.78),
                          ),
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
                      ),
                    ],
                  ),
                )
              : wardrobeProvider.wardrobes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    scheme.primary.withValues(alpha: 0.18),
                                    WardrobeTokens.emeraldCard,
                                  ],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: WardrobeTokens.outlineGold,
                                ),
                              ),
                              child: Icon(
                                Icons.inventory_2_rounded,
                                size: 48,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'No Wardrobes Yet',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Create your first wardrobe to organize\nyour clothes and keep them organized!',
                              style: TextStyle(
                                fontSize: 14,
                                color: scheme.onSurface.withValues(alpha: 0.72),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const CreateWardrobeScreen(),
                                    ),
                                  ).then((_) => _loadWardrobes());
                                },
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Create Wardrobe'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        _loadWardrobes();
                        _loadBanners();
                        await Future.delayed(const Duration(milliseconds: 500));
                      },
                      color: const Color(0xFF043915),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: (_banners.isNotEmpty ? 1 : 0) + wardrobeProvider.wardrobes.length,
                        itemBuilder: (context, index) {
                          // Show banner slider as first item if available
                          if (_banners.isNotEmpty && index == 0) {
                            return BannerSliderWidget(
                              banners: _banners,
                              width: double.infinity,
                              height: 100,
                            );
                          }
                          // Adjust index for wardrobe items
                          final wardrobeIndex = _banners.isNotEmpty ? index - 1 : index;
                          final wardrobe = wardrobeProvider.wardrobes[wardrobeIndex];
                          return TweenAnimationBuilder<double>(
                            duration: Duration(milliseconds: 300 + (wardrobeIndex * 50)),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: WardrobeCard(
                              wardrobe: wardrobe,
                              onTap: widget.selectionMode ? () {
                                // In selection mode, set selected wardrobe and pop back
                                wardrobeProvider.setSelectedWardrobe(wardrobe);
                                Navigator.of(context).pop();
                              } : () {
                                _openWardrobeAssets(wardrobe);
                              },
                              // Only show edit/delete buttons if not in selection mode
                              onEdit: widget.selectionMode ? null : () {
                                _editWardrobe(wardrobe, authProvider.user!.uid);
                              },
                              onDelete: widget.selectionMode ? null : () {
                                _deleteWardrobe(wardrobe.id, authProvider.user!.uid);
                              },
                            ),
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
        final dialogContext = context;
        if (!dialogContext.mounted) return;
        await showDialog(
          context: dialogContext,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: Colors.orange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Cannot Delete Wardrobe',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This wardrobe contains $clothesCount item(s).\n\n'
                    'You need to arrange your clothes in the right place before removing the wardrobe.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF043915),
                            Color(0xFF9F7AEA),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: const Text(
                              'OK',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        return;
      }
    } catch (e) {
      // If check fails, show error and return
      if (!context.mounted) return;
      final snackContext = context;
      if (!snackContext.mounted) return;
      ScaffoldMessenger.of(snackContext).showSnackBar(
        SnackBar(
          content: Text('Failed to check wardrobe: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // If no clothes, show confirmation dialog
    if (!context.mounted) return;
    final dialogContext = context;
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
          child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_rounded,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Delete Wardrobe?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete this wardrobe?\nThis action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, true),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: const Text(
                              'Delete',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      final providerContext = context;
      final wardrobeProvider = Provider.of<WardrobeProvider>(providerContext, listen: false);
      await wardrobeProvider.deleteWardrobe(userId: userId, wardrobeId: wardrobeId);
      if (!providerContext.mounted) return;
      if (wardrobeProvider.errorMessage != null) {
        ScaffoldMessenger.of(providerContext).showSnackBar(
          SnackBar(
            content: Text(wardrobeProvider.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        if (!providerContext.mounted) return;
        ScaffoldMessenger.of(providerContext).showSnackBar(
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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF043915),
                            Color(0xFF9F7AEA),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Edit Wardrobe',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      color: Colors.grey[600],
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Name field
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Wardrobe Name',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: Icon(Icons.title_rounded, color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF043915),
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Location field
                TextFormField(
                  controller: _locationController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Location',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: Icon(Icons.location_on_rounded, color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF043915),
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a location';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: TextButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF043915),
                              Color(0xFF9F7AEA),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF043915).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isLoading ? null : _saveWardrobe,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_rounded,
                                            color: Colors.white, size: 14),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Save',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

