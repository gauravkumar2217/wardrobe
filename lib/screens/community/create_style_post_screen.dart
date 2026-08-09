import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/style_post_service.dart';
import '../../widgets/shell_back_button.dart';

/// Create a Style Feed post (real look photo — not a wardrobe item).
class CreateStylePostScreen extends StatefulWidget {
  const CreateStylePostScreen({super.key});

  @override
  State<CreateStylePostScreen> createState() => _CreateStylePostScreenState();
}

class _CreateStylePostScreenState extends State<CreateStylePostScreen> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  File? _image;
  String _visibility = 'friends';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 88,
    );
    if (file == null || !mounted) return;
    setState(() => _image = File(file.path));
  }

  Future<void> _submit() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a photo of your look')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    setState(() => _isSubmitting = true);
    try {
      await StylePostService.createPost(
        imageFile: _image!,
        caption: _captionController.text.trim(),
        visibility: _visibility,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Style posted! Friends can see it in All Styles.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
              child: ShellBackButton(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text(
                    'Post your style',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Share a real photo of how you look. This is not your wardrobe inventory — wardrobe items are saved when you scan a photo.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.72),
                        ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _isSubmitting
                        ? null
                        : () {
                            showModalBottomSheet(
                              context: context,
                              builder: (ctx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.camera_alt),
                                      title: const Text('Take photo'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _pick(ImageSource.camera);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title: const Text('Choose from gallery'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _pick(ImageSource.gallery);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                    child: Container(
                      height: 320,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade400),
                        color: Colors.black12,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _image != null
                          ? Image.file(_image!, fit: BoxFit.cover)
                          : const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 40),
                                  SizedBox(height: 8),
                                  Text('Add your look photo'),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _captionController,
                    maxLines: 3,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Caption (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Who can see this?',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'friends', label: Text('Friends')),
                      ButtonSegment(value: 'public', label: Text('Public')),
                      ButtonSegment(value: 'private', label: Text('Only me')),
                    ],
                    selected: {_visibility},
                    onSelectionChanged: _isSubmitting
                        ? null
                        : (s) => setState(() => _visibility = s.first),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF043915),
                        foregroundColor: Colors.white,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Post to Style Feed'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
