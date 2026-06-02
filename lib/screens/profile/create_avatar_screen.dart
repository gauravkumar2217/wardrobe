import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../services/avatar_2d_service.dart';
import '../../services/user_service.dart';
import '../../models/avatar.dart';

/// Create Avatar screen for capturing a single full-body photo and generating 2D avatar
class CreateAvatarScreen extends StatefulWidget {
  const CreateAvatarScreen({super.key});

  @override
  State<CreateAvatarScreen> createState() => _CreateAvatarScreenState();
}

class _CreateAvatarScreenState extends State<CreateAvatarScreen> {
  final _heightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Single full-body image
  File? _bodyImage;

  Avatar? _existingAvatar;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadExistingAvatar();
  }

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingAvatar() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    try {
      final avatar = await UserService.getAvatar(authProvider.user!.uid);
      if (mounted) {
        setState(() {
          _existingAvatar = avatar;
          if (avatar?.userHeightCm != null) {
            _heightController.text = avatar!.userHeightCm!.toStringAsFixed(0);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading avatar: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile == null) return;

      if (mounted) {
        setState(() {
          _bodyImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _createAvatar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_bodyImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture a full-body photo')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    final userHeightCm = double.tryParse(_heightController.text);
    if (userHeightCm == null || userHeightCm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid height')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      // Use 2D avatar generation service
      final avatar = await Avatar2DService.generateAvatar(
        userId: authProvider.user!.uid,
        bodyImageFile: _bodyImage!,
        userHeightCm: userHeightCm,
      );

      if (mounted) {
        setState(() {
          _isCreating = false;
          _existingAvatar = avatar;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating avatar: $e')),
        );
      }
    }
  }

  Widget _buildImagePreview() {
    return Container(
      height: 400,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: _bodyImage != null ? Colors.green : Colors.grey,
          width: _bodyImage != null ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _bodyImage != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.file(_bodyImage!, fit: BoxFit.cover),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt,
                    color: Colors.grey[400],
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Full Body Photo',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to capture or choose from gallery',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Create Avatar'),
        backgroundColor: const Color(0xFF043915),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        minimum: EdgeInsets.zero,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + keyboardInset),
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instructions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Instructions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Capture a single full-body photo:\n'
                        '• Stand straight with arms slightly away from body\n'
                        '• Face the camera directly\n'
                        '• Ensure good lighting\n'
                        '• Full body should be visible from head to toe\n\n'
                        'The AI will create a clean avatar with transparent background.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Body image section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Full Body Photo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _isCreating
                        ? null
                        : () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.camera_alt),
                                      title: const Text('Take Photo'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _pickImage(ImageSource.camera);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title: const Text('Choose from Gallery'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _pickImage(ImageSource.gallery);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                    child: _buildImagePreview(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Height input
              if (_bodyImage != null) ...[
                TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Your Height (cm)',
                    hintText: 'Enter your height in centimeters',
                    prefixIcon: Icon(Icons.height),
                    helperText: 'Required for accurate measurements',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your height';
                    }
                    final height = double.tryParse(value);
                    if (height == null || height <= 0 || height > 300) {
                      return 'Please enter a valid height (1-300 cm)';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Create Avatar button
                ElevatedButton(
                  onPressed:
                      (_isCreating || _bodyImage == null) ? null : _createAvatar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF043915),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isCreating
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Creating Avatar...'),
                          ],
                        )
                      : const Text('Create Avatar'),
                ),
              ],

              // Existing avatar info
              if (_existingAvatar != null && _existingAvatar!.isGenerated) ...[
                const SizedBox(height: 24),
                Card(
                  color: Colors.green.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              'Avatar Created',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        if (_existingAvatar!.createdAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Created: ${_existingAvatar!.createdAt!.toString().split(' ')[0]}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}
