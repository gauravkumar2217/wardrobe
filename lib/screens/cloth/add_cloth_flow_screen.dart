import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/cloth.dart';
import '../../models/detected_cloth_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cloth_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../services/cloth_detection_service.dart';
import '../../services/cloth_service.dart';
import '../../theme/wardrobe_tokens.dart';
import '../../widgets/shell_back_button.dart';
import 'add_cloth_screen.dart';

enum _FlowStep { source, analyzing, select, extracting, review, saving }

/// Multi-item AI clothing upload flow.
class AddClothFlowScreen extends StatefulWidget {
  final String wardrobeId;

  const AddClothFlowScreen({super.key, required this.wardrobeId});

  @override
  State<AddClothFlowScreen> createState() => _AddClothFlowScreenState();
}

class _AddClothFlowScreenState extends State<AddClothFlowScreen> {
  final ImagePicker _picker = ImagePicker();

  _FlowStep _step = _FlowStep.source;
  String? _sessionId;
  File? _sourceImage;
  List<DetectedClothItem> _detected = [];
  final Set<String> _selectedIds = {};
  List<DetectedClothItem> _extracted = [];
  String? _error;
  int _saveProgress = 0;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;

      setState(() {
        _sourceImage = File(file.path);
        _step = _FlowStep.analyzing;
        _error = null;
      });

      final result = await ClothDetectionService.detectItems(_sourceImage!);
      if (!mounted) return;

      setState(() {
        _sessionId = result.sessionId;
        _detected = result.items;
        _selectedIds
          ..clear()
          ..addAll(result.items.map((e) => e.id));
        _step = _FlowStep.select;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _step = _FlowStep.source;
      });
    }
  }

  Future<void> _extractSelected() async {
    if (_sessionId == null || _selectedIds.isEmpty) return;

    setState(() {
      _step = _FlowStep.extracting;
      _error = null;
    });

    try {
      final items = await ClothDetectionService.extractItems(
        sessionId: _sessionId!,
        itemIds: _selectedIds.toList(),
      );
      if (!mounted) return;
      setState(() {
        _extracted = items;
        _step = _FlowStep.review;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _step = _FlowStep.select;
      });
    }
  }

  Future<void> _saveAll() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.uid;
    if (userId == null || _extracted.isEmpty) return;

    setState(() {
      _step = _FlowStep.saving;
      _saveProgress = 0;
      _error = null;
    });

    final wardrobeProvider =
        Provider.of<WardrobeProvider>(context, listen: false);
    var saved = 0;

    try {
      for (var i = 0; i < _extracted.length; i++) {
        final item = _extracted[i];
        final imageUrl = item.processedImageUrl ?? item.imageUrl;
        if (imageUrl == null || imageUrl.isEmpty) continue;

        await ClothService.createClothFromUrls(
          wardrobeId: widget.wardrobeId,
          imageUrl: imageUrl,
          processedImageUrl: item.processedImageUrl,
          hasProcessedImage: item.hasProcessedImage,
          season: item.season,
          placement: 'Wardrobe',
          colorTags: ColorTags(primary: item.color, colors: [item.color]),
          clothType: item.clothType,
          category: item.category,
          occasions: item.occasions.isNotEmpty ? item.occasions : ['Casual'],
          itemKind: item.itemKind,
          aiDetected: {
            'cloth_type': item.clothType,
            'colors': [item.color],
            'confidence': item.confidence,
            'detected_at': DateTime.now().toIso8601String(),
            'item_kind': item.itemKind,
            'material': item.material,
            'pattern': item.pattern,
            'brand': item.brand,
            'style_tags': item.styleTags,
          },
        );
        saved++;
        if (mounted) setState(() => _saveProgress = i + 1);
      }

      await wardrobeProvider.refreshWardrobeCount(
        userId: userId,
        wardrobeId: widget.wardrobeId,
      );

      final clothProvider = Provider.of<ClothProvider>(context, listen: false);
      await clothProvider.loadClothes(
        userId: userId,
        wardrobeId: widget.wardrobeId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$saved item${saved == 1 ? '' : 's'} added to wardrobe'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _step = _FlowStep.review;
      });
    }
  }

  void _openManualAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddClothScreen(wardrobeId: widget.wardrobeId),
      ),
    ).then((_) {
      if (mounted) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
              child: Row(
                children: [
                  const Expanded(child: ShellBackButton()),
                  if (_step == _FlowStep.source)
                    TextButton(
                      onPressed: _openManualAdd,
                      child: const Text('Manual'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _step == _FlowStep.source) {
      return _errorView(_error!, onRetry: () => setState(() => _error = null));
    }

    switch (_step) {
      case _FlowStep.source:
        return _sourceStep();
      case _FlowStep.analyzing:
        return _loadingStep('Detecting clothing items with AI...');
      case _FlowStep.select:
        return _selectStep();
      case _FlowStep.extracting:
        return _loadingStep('Creating clean thumbnails for selected items...');
      case _FlowStep.review:
        return _reviewStep();
      case _FlowStep.saving:
        return _loadingStep(
          'Saving $_saveProgress / ${_extracted.length} items...',
        );
    }
  }

  Widget _sourceStep() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Add one photo — AI can detect multiple clothing items at once.',
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.78),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        _SourceCard(
          icon: Icons.camera_alt_rounded,
          title: 'Take Photo',
          subtitle: 'Use camera',
          onTap: () => _pick(ImageSource.camera),
        ),
        const SizedBox(height: 12),
        _SourceCard(
          icon: Icons.photo_library_rounded,
          title: 'Upload from Gallery',
          subtitle: 'Choose existing photo',
          onTap: () => _pick(ImageSource.gallery),
        ),
      ],
    );
  }

  Widget _selectStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_sourceImage != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _sourceImage!,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'Which items would you like to add to your wardrobe?',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: ListView.builder(
            itemCount: _detected.length,
            itemBuilder: (context, index) {
              final item = _detected[index];
              final selected = _selectedIds.contains(item.id);
              return CheckboxListTile(
                value: selected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedIds.add(item.id);
                    } else {
                      _selectedIds.remove(item.id);
                    }
                  });
                },
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${item.category} · ${item.color}'
                  '${item.material != null ? ' · ${item.material}' : ''}',
                ),
                secondary: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  child: Icon(
                    _iconForKind(item.itemKind),
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            },
          ),
        ),
        FilledButton(
          onPressed: _selectedIds.isEmpty ? null : _extractSelected,
          child: Text('Continue (${_selectedIds.length} selected)'),
        ),
      ],
    );
  }

  Widget _reviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Review AI-filled details. You can edit before saving.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: _extracted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _extracted[index];
              final imageUrl = item.processedImageUrl ?? item.imageUrl;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                              )
                            : _thumbPlaceholder(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text('${item.category} · ${item.clothType}'),
                            Text('Color: ${item.color} · Season: ${item.season}'),
                            if (item.styleTags.isNotEmpty)
                              Text(
                                item.styleTags.join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
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
        FilledButton(
          onPressed: _saveAll,
          child: Text('Add ${_extracted.length} item${_extracted.length == 1 ? '' : 's'}'),
        ),
      ],
    );
  }

  Widget _loadingStep(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView(String message, {required VoidCallback onRetry}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 72,
      height: 72,
      color: Colors.grey.shade300,
      child: const Icon(Icons.checkroom_outlined),
    );
  }

  IconData _iconForKind(String kind) {
    switch (kind) {
      case 'footwear':
        return Icons.ice_skating_rounded;
      case 'accessories':
        return Icons.watch_rounded;
      case 'makeup':
        return Icons.brush_rounded;
      default:
        return Icons.checkroom_rounded;
    }
  }
}

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WardrobeTokens.outlineGold.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurface.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
