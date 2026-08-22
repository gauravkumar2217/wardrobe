import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cloth.dart';
import '../../models/saved_outfit.dart';
import '../../providers/auth_provider.dart';
import '../../services/cloth_service.dart';
import '../../services/saved_outfit_service.dart';
import '../../theme/wardrobe_tokens.dart';
import '../../utils/outfit_slot_classifier.dart';
import '../../utils/outfit_slots.dart';

/// Build outfit combos by category and save collections to the user's account.
class OutfitGeneratorScreen extends StatefulWidget {
  const OutfitGeneratorScreen({super.key});

  @override
  State<OutfitGeneratorScreen> createState() => _OutfitGeneratorScreenState();
}

class _OutfitGeneratorScreenState extends State<OutfitGeneratorScreen> {
  static const _brand = Color(0xFF043915);

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Cloth> _clothes = [];
  List<SavedOutfit> _saved = [];
  Map<String, String?> _slots = OutfitSlots.empty();
  String _activeSlot = 'top';
  String? _editingOutfitId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.user?.uid;
      if (userId == null) throw Exception('Not signed in');

      final results = await Future.wait([
        ClothService.getAllUserClothes(userId),
        SavedOutfitService.getSavedOutfits(),
      ]);

      if (!mounted) return;
      setState(() {
        _clothes = results[0] as List<Cloth>;
        _saved = results[1] as List<SavedOutfit>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Cloth? _clothById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final c in _clothes) {
      if (c.id == id) return c;
    }
    return null;
  }

  String _clothImageUrl(Cloth c) {
    if (c.processedImageUrl != null && c.processedImageUrl!.isNotEmpty) {
      return c.processedImageUrl!;
    }
    return c.imageUrl;
  }

  bool get _hasSelection =>
      _slots.values.any((id) => id != null && id.isNotEmpty);

  void _selectItem(Cloth cloth) {
    setState(() {
      _slots[_activeSlot] = cloth.id;
    });
  }

  void _clearSlot(String slotKey) {
    setState(() => _slots[slotKey] = null);
  }

  void _resetBuilder() {
    setState(() {
      _slots = OutfitSlots.empty();
      _editingOutfitId = null;
      _activeSlot = 'top';
    });
  }

  void _loadSavedIntoBuilder(SavedOutfit outfit) {
    setState(() {
      _slots = Map<String, String?>.from(outfit.slots);
      _editingOutfitId = outfit.id;
      _activeSlot = OutfitSlots.all.firstWhere(
        (k) => _slots[k] != null && _slots[k]!.isNotEmpty,
        orElse: () => 'top',
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Editing "${outfit.name}"')),
    );
  }

  Future<void> _saveOutfit() async {
    if (!_hasSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one item for your combo')),
      );
      return;
    }

    final nameController = TextEditingController(
      text: _editingOutfitId != null
          ? _saved
              .firstWhere(
                (o) => o.id == _editingOutfitId,
                orElse: () => SavedOutfit(
                  id: '',
                  userId: '',
                  name: 'My outfit',
                  slots: OutfitSlots.empty(),
                ),
              )
              .name
          : 'My outfit ${DateTime.now().day}/${DateTime.now().month}',
    );

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_editingOutfitId != null ? 'Update collection' : 'Save collection'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Collection name',
            hintText: 'e.g. Office Friday',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    setState(() => _saving = true);
    try {
      if (_editingOutfitId != null) {
        await SavedOutfitService.update(
          outfitId: _editingOutfitId!,
          name: name,
          slots: _slots,
        );
      } else {
        await SavedOutfitService.create(name: name, slots: _slots);
      }
      if (!mounted) return;
      _resetBuilder();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Outfit collection saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteOutfit(SavedOutfit outfit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete collection?'),
        content: Text('Remove "${outfit.name}" from your saved outfits?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await SavedOutfitService.delete(outfit.id);
      if (_editingOutfitId == outfit.id) _resetBuilder();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: WardrobeTokens.emeraldBg,
      appBar: AppBar(
        backgroundColor: WardrobeTokens.emeraldBg,
        title: const Text('Outfit Generator'),
        centerTitle: true,
        actions: [
          if (_hasSelection)
            TextButton(
              onPressed: _saving ? null : _resetBuilder,
              child: const Text('Clear'),
            ),
        ],
      ),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving || !_hasSelection ? null : _saveOutfit,
              backgroundColor: _brand,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_editingOutfitId != null ? 'Update' : 'Save combo'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildSavedSection(scheme)),
                      SliverToBoxAdapter(child: _buildComboPreview(scheme)),
                      SliverToBoxAdapter(child: _buildSlotTabs(scheme)),
                      _buildItemGrid(scheme),
                      const SliverPadding(padding: EdgeInsets.only(bottom: 88)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSavedSection(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My collections',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a saved combo to edit it',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
          ),
          const SizedBox(height: 12),
          if (_saved.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: WardrobeTokens.outlineGold),
                color: const Color(0xFF06231E),
              ),
              child: Text(
                'No saved combos yet. Pick items below and tap Save combo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _saved.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final outfit = _saved[i];
                  return _SavedOutfitChip(
                    outfit: outfit,
                    isActive: _editingOutfitId == outfit.id,
                    onTap: () => _loadSavedIntoBuilder(outfit),
                    onDelete: () => _deleteOutfit(outfit),
                  );
                },
              ),
            ),
          const SizedBox(height: 18),
          Text(
            'Build your combo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose one item per category — top, bottom, footwear, accessories & beauty',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildComboPreview(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WardrobeTokens.outlineGold),
          color: const Color(0xFF06231E),
        ),
        child: Row(
          children: [
            for (final key in OutfitSlots.all) ...[
              Expanded(
                child: _SlotPreviewTile(
                  label: OutfitSlots.labels[key] ?? key,
                  cloth: _clothById(_slots[key]),
                  imageUrl: () {
                    final c = _clothById(_slots[key]);
                    return c != null ? _clothImageUrl(c) : null;
                  }(),
                  isActive: _activeSlot == key,
                  onTap: () => setState(() => _activeSlot = key),
                  onClear: _slots[key] != null ? () => _clearSlot(key) : null,
                ),
              ),
              if (key != OutfitSlots.all.last) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSlotTabs(ColorScheme scheme) {
    final slotClothes = OutfitSlotClassifier.filterForSlot(_clothes, _activeSlot);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Pick ${OutfitSlots.labels[_activeSlot] ?? _activeSlot}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Text(
            '${slotClothes.length} items',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemGrid(ColorScheme scheme) {
    final items = OutfitSlotClassifier.filterForSlot(_clothes, _activeSlot);

    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No ${OutfitSlots.labels[_activeSlot]?.toLowerCase() ?? _activeSlot} items in your wardrobe yet.\nAdd items from your wardrobe first.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final cloth = items[i];
            final selected = _slots[_activeSlot] == cloth.id;
            return _ClothPickTile(
              cloth: cloth,
              imageUrl: _clothImageUrl(cloth),
              selected: selected,
              onTap: () => _selectItem(cloth),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }
}

class _SavedOutfitChip extends StatelessWidget {
  final SavedOutfit outfit;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SavedOutfitChip({
    required this.outfit,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = outfit.previewImageUrl;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 108,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? scheme.primary : WardrobeTokens.outlineGold,
            width: isActive ? 2 : 1,
          ),
          color: const Color(0xFF06231E),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: preview != null && preview.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: preview,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: (_, __, ___) =>
                            _placeholder(scheme),
                      )
                    : _placeholder(scheme),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              outfit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Row(
              children: [
                Text(
                  '${outfit.itemCount} pcs',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(Icons.close, size: 14, color: scheme.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.primary.withValues(alpha: 0.12),
      child: Center(
        child: Icon(Icons.checkroom, color: scheme.primary.withValues(alpha: 0.7)),
      ),
    );
  }
}

class _SlotPreviewTile extends StatelessWidget {
  final String label;
  final Cloth? cloth;
  final String? imageUrl;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _SlotPreviewTile({
    required this.label,
    required this.cloth,
    required this.imageUrl,
    required this.isActive,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? scheme.primary : WardrobeTokens.outlineGold.withValues(alpha: 0.5),
            width: isActive ? 2 : 1,
          ),
          color: isActive
              ? scheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imageUrl != null && imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _empty(scheme),
                          )
                        : _empty(scheme),
                  ),
                  if (onClear != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: onClear,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
            ),
            if (cloth != null)
              Text(
                cloth!.clothType,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 8,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _empty(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.primary.withValues(alpha: 0.08),
      child: Icon(Icons.add, size: 18, color: scheme.primary.withValues(alpha: 0.6)),
    );
  }
}

class _ClothPickTile extends StatelessWidget {
  final Cloth cloth;
  final String imageUrl;
  final bool selected;
  final VoidCallback onTap;

  const _ClothPickTile({
    required this.cloth,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : WardrobeTokens.outlineGold,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: scheme.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.checkroom),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
              child: Text(
                cloth.clothType,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
