import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../services/body_scan_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import '../../services/device_capability_service.dart';
import '../../services/image_processing_service.dart';
import '../../models/body_profile.dart';

/// Body scan screen for capturing and processing body profile
class BodyScanScreen extends StatefulWidget {
  const BodyScanScreen({super.key});

  @override
  State<BodyScanScreen> createState() => _BodyScanScreenState();
}

class _BodyScanScreenState extends State<BodyScanScreen> {
  final _heightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  File? _selectedImage;
  BodyProfile? _existingBodyProfile;
  bool _isScanning = false;
  bool _isDeviceCapable = true;
  String? _capabilityMessage;

  @override
  void initState() {
    super.initState();
    _checkDeviceCapability();
    _loadExistingBodyProfile();
  }

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _checkDeviceCapability() async {
    final isCapable = await DeviceCapabilityService.isDeviceCapable();
    final message = await DeviceCapabilityService.getCapabilityMessage();
    
    setState(() {
      _isDeviceCapable = isCapable;
      _capabilityMessage = message;
    });
  }

  Future<void> _loadExistingBodyProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    try {
      final bodyProfile = await UserService.getBodyProfile(authProvider.user!.uid);
      if (mounted) {
        setState(() {
          _existingBodyProfile = bodyProfile;
          if (bodyProfile?.userHeightCm != null) {
            _heightController.text = bodyProfile!.userHeightCm!.toStringAsFixed(0);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading body profile: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 720, // Important for iOS performance
        preferredCameraDevice: CameraDevice.front,
      );

      if (pickedFile == null) return;

      final imageFile = File(pickedFile.path);

      // Process image for body scan (HEIC conversion, resize, compress)
      final processedImage = await ImageProcessingService.processImageForBodyScan(imageFile);
      
      if (processedImage == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to process image')),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _selectedImage = processedImage;
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

  Future<void> _scanBody() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
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
      _isScanning = true;
    });

    try {
      // Step 1: Scan body and get landmarks
      final bodyProfile = await BodyScanService.scanBody(
        userId: authProvider.user!.uid,
        imageFile: _selectedImage!,
        userHeightCm: userHeightCm,
      );

      if (bodyProfile == null) {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to detect body pose. Please try again with a full-body photo.'),
            ),
          );
        }
        return;
      }

      // Step 2: Upload body image
      final imageUrl = await StorageService.uploadBodyProfileImage(
        userId: authProvider.user!.uid,
        imageFile: _selectedImage!,
      );

      // Step 3: Update body profile with image URL
      final updatedProfile = bodyProfile.copyWith(
        bodyImageUrl: imageUrl,
        processedBodyImageUrl: imageUrl, // For now, use same image
      );

      // Step 4: Save body profile
      await UserService.saveBodyProfile(updatedProfile);

      if (mounted) {
        setState(() {
          _isScanning = false;
          _existingBodyProfile = updatedProfile;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Body scan completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning body: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Body Scan'),
        backgroundColor: const Color(0xFF043915),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Device capability warning
              if (!_isDeviceCapable && _capabilityMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _capabilityMessage!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

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
                        '1. Take a full-body photo in front-facing camera\n'
                        '2. Stand straight with arms slightly away from body\n'
                        '3. Ensure good lighting\n'
                        '4. Enter your height for accurate measurements',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Image preview
              if (_selectedImage != null || _existingBodyProfile?.bodyImageUrl != null)
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _selectedImage != null
                        ? Image.file(_selectedImage!, fit: BoxFit.contain)
                        : _existingBodyProfile?.bodyImageUrl != null
                            ? Image.network(
                                _existingBodyProfile!.bodyImageUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.error_outline),
                                  );
                                },
                              )
                            : null,
                  ),
                )
              else
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[100],
                  ),
                  child: const Center(
                    child: Icon(Icons.person, size: 64, color: Colors.grey),
                  ),
                ),

              const SizedBox(height: 16),

              // Image selection buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isScanning ? null : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isScanning ? null : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Choose from Gallery'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Height input
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

              const SizedBox(height: 32),

              // Scan button
              ElevatedButton(
                onPressed: (_isScanning || _selectedImage == null) ? null : _scanBody,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF043915),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isScanning
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
                          Text('Scanning...'),
                        ],
                      )
                    : const Text('Scan Body'),
              ),

              // Existing body profile info
              if (_existingBodyProfile != null) ...[
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
                              'Body Profile Saved',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        if (_existingBodyProfile!.measurements != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Shoulder Width: ${_existingBodyProfile!.measurements!.shoulderWidthCm?.toStringAsFixed(1) ?? "N/A"} cm',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Hip Width: ${_existingBodyProfile!.measurements!.hipWidthCm?.toStringAsFixed(1) ?? "N/A"} cm',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                        if (_existingBodyProfile!.scannedAt != null)
                          Text(
                            'Scanned: ${_existingBodyProfile!.scannedAt!.toString().split(' ')[0]}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
    );
  }
}
