import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/avatar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../services/avatar_2d_service.dart';
import '../../services/user_service.dart';
import '../../widgets/shell_back_button.dart';

/// Create Avatar screen for capturing a single full-body photo and generating 2D avatar.
class CreateAvatarScreen extends StatefulWidget {
  const CreateAvatarScreen({super.key});

  @override
  State<CreateAvatarScreen> createState() => _CreateAvatarScreenState();
}

class _CreateAvatarScreenState extends State<CreateAvatarScreen> {
  final _heightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  File? _bodyImage;
  Avatar? _existingAvatar;
  bool _isSubmitting = false;
  bool _isRetrying = false;
  String? _statusMessage;
  Timer? _uiPollTimer;

  @override
  void initState() {
    super.initState();
    Avatar2DService.addStatusListener(_onAvatarStatusUpdate);
    _loadExistingAvatar();
  }

  @override
  void dispose() {
    Avatar2DService.removeStatusListener(_onAvatarStatusUpdate);
    _uiPollTimer?.cancel();
    _heightController.dispose();
    super.dispose();
  }

  void _onAvatarStatusUpdate(Avatar avatar) {
    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.uid;

    // FCM may emit a lightweight status — refresh full avatar record.
    if (userId != null &&
        (avatar.userId == 'self' || avatar.isGenerated || avatar.isFailed)) {
      Avatar2DService.refreshAvatar(userId).then((full) {
        if (!mounted) return;
        final resolved = full ?? avatar;
        setState(() {
          _existingAvatar = resolved;
          _isSubmitting = false;
          _isRetrying = false;
          if (resolved.isGenerated) {
            _statusMessage =
                'Your avatar is ready. You can use it for Try-On.';
          } else if (resolved.isFailed) {
            _statusMessage =
                resolved.errorMessage?.trim().isNotEmpty == true
                    ? resolved.errorMessage
                    : 'Avatar creation failed. You can retry.';
          } else if (resolved.isGenerating) {
            _statusMessage =
                'Avatar is creating. We will notify you when it is ready. This may take a few minutes.';
          }
        });
        if (!resolved.isGenerating) {
          _uiPollTimer?.cancel();
        }
      });
      return;
    }

    setState(() {
      _existingAvatar = avatar;
      if (avatar.isGenerated) {
        _statusMessage = 'Your avatar is ready. You can use it for Try-On.';
        _isSubmitting = false;
        _isRetrying = false;
      } else if (avatar.isFailed) {
        _statusMessage =
            avatar.errorMessage?.trim().isNotEmpty == true
                ? avatar.errorMessage
                : 'Avatar creation failed. You can retry.';
        _isSubmitting = false;
        _isRetrying = false;
      } else if (avatar.isGenerating) {
        _statusMessage =
            'Avatar is creating. We will notify you when it is ready. This may take a few minutes.';
      }
    });
  }

  Future<void> _loadExistingAvatar() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;
    final userId = authProvider.user!.uid;

    try {
      final avatar = await UserService.getAvatar(userId);
      final pendingId = await Avatar2DService.getPendingAvatarId(userId);

      if (!mounted) return;

      setState(() {
        _existingAvatar = avatar;
        if (avatar?.userHeightCm != null) {
          _heightController.text = avatar!.userHeightCm!.toStringAsFixed(0);
        }
      });

      if (avatar != null && avatar.isGenerating) {
        final avatarId = avatar.generationJobId ?? pendingId;
        if (avatarId != null) {
          await Avatar2DService.savePendingAvatarId(
            userId: userId,
            avatarId: avatarId,
          );
          Avatar2DService.startBackgroundPolling(
            userId: userId,
            avatarId: avatarId,
          );
          _startUiPolling(userId);
          setState(() {
            _statusMessage =
                'Avatar is creating. We will notify you when it is ready. This may take a few minutes.';
          });
        }
      } else if (pendingId != null && (avatar == null || !avatar.isGenerated)) {
        // Pending job exists — refresh status.
        try {
          final status = await Avatar2DService.getAvatarStatus(pendingId);
          final s = status['generation_status']?.toString();
          if (s == 'pending' || s == 'processing') {
            Avatar2DService.startBackgroundPolling(
              userId: userId,
              avatarId: pendingId,
            );
            _startUiPolling(userId);
            setState(() {
              _existingAvatar = (avatar ?? Avatar(userId: userId)).copyWith(
                generationStatus: s,
                generationJobId: pendingId,
              );
              _statusMessage =
                  'Avatar is creating. We will notify you when it is ready. This may take a few minutes.';
            });
          } else if (s == 'failed') {
            setState(() {
              _existingAvatar = (avatar ?? Avatar(userId: userId)).copyWith(
                generationStatus: 'failed',
                generationJobId: pendingId,
                errorMessage: status['error_message']?.toString(),
              );
              _statusMessage =
                  status['error_message']?.toString() ??
                  'Avatar creation failed. You can retry.';
            });
            await Avatar2DService.clearPendingAvatarId();
          } else if (s == 'completed') {
            final refreshed = await Avatar2DService.refreshAvatar(userId);
            if (mounted && refreshed != null) {
              setState(() {
                _existingAvatar = refreshed;
                _statusMessage =
                    'Your avatar is ready. You can use it for Try-On.';
              });
            }
            await Avatar2DService.clearPendingAvatarId();
          }
        } catch (e) {
          debugPrint('Error checking pending avatar: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading avatar: $e');
    }
  }

  void _startUiPolling(String userId) {
    _uiPollTimer?.cancel();
    _uiPollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      final avatar = await Avatar2DService.refreshAvatar(userId);
      if (!mounted || avatar == null) return;
      if (avatar.isGenerating) {
        setState(() {
          _existingAvatar = avatar;
          _statusMessage ??=
              'Avatar is creating. We will notify you when it is ready. This may take a few minutes.';
        });
        return;
      }
      _uiPollTimer?.cancel();
      setState(() {
        _existingAvatar = avatar;
        _isSubmitting = false;
        _isRetrying = false;
        if (avatar.isGenerated) {
          _statusMessage =
              'Your avatar is ready. You can use it for Try-On.';
        } else if (avatar.isFailed) {
          _statusMessage =
              avatar.errorMessage?.trim().isNotEmpty == true
                  ? avatar.errorMessage
                  : 'Avatar creation failed. You can retry.';
        }
      });
    });
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
      _isSubmitting = true;
      _statusMessage = 'Uploading your photo and starting avatar creation…';
    });

    try {
      final userId = authProvider.user!.uid;
      final result = await Avatar2DService.startAvatarGeneration(
        userId: userId,
        bodyImageFile: _bodyImage!,
        userHeightCm: userHeightCm,
      );

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _existingAvatar = (_existingAvatar ?? Avatar(userId: userId)).copyWith(
          generationStatus: result.generationStatus,
          generationJobId: result.avatarId,
          userHeightCm: userHeightCm,
          errorMessage: null,
        );
        _statusMessage =
            'Avatar is creating. We will notify you when it is ready. This may take a few minutes — you can leave this screen.';
      });

      _startUiPolling(userId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _statusMessage = 'Could not start avatar creation. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating avatar: $e')),
        );
      }
    }
  }

  Future<void> _retryAvatar() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;
    final userId = authProvider.user!.uid;
    final avatarId = _existingAvatar?.generationJobId;

    setState(() {
      _isRetrying = true;
      _statusMessage = 'Retrying avatar creation…';
    });

    try {
      if (avatarId != null && avatarId.isNotEmpty) {
        final result = await Avatar2DService.retryAvatarGeneration(
          userId: userId,
          avatarId: avatarId,
        );

        if (!mounted) return;

        if (result.generationStatus == 'completed') {
          final refreshed = await Avatar2DService.refreshAvatar(userId);
          setState(() {
            _isRetrying = false;
            _existingAvatar = refreshed;
            _statusMessage =
                'Your avatar is ready. You can use it for Try-On.';
          });
          return;
        }

        setState(() {
          _isRetrying = false;
          _existingAvatar =
              (_existingAvatar ?? Avatar(userId: userId)).copyWith(
            generationStatus: result.generationStatus,
            generationJobId: result.avatarId,
            errorMessage: null,
          );
          _statusMessage =
              'Avatar is creating. We will notify you when it is ready. This may take a few minutes.';
        });
        _startUiPolling(userId);
        return;
      }

      // No server avatar id — need a fresh upload.
      if (_bodyImage != null) {
        await _createAvatar();
        return;
      }

      if (mounted) {
        setState(() {
          _isRetrying = false;
          _statusMessage =
              'Please upload a full-body photo again to retry.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRetrying = false;
          _statusMessage = 'Retry failed. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Retry failed: $e')),
        );
      }
    }
  }

  void _openTryOn() {
    try {
      context.read<NavigationProvider>().navigateToTryOn();
    } catch (_) {}
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildImagePreview() {
    final busy = _isSubmitting ||
        _isRetrying ||
        (_existingAvatar?.isGenerating ?? false);

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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_bodyImage!, fit: BoxFit.cover),
                  if (busy)
                    Container(
                      color: Colors.black45,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(color: Colors.white),
                    ),
                ],
              ),
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

  Widget _buildStatusCard() {
    final avatar = _existingAvatar;
    if (avatar == null && _statusMessage == null) {
      return const SizedBox.shrink();
    }

    if (avatar != null && avatar.isGenerated) {
      final imageUrl =
          avatar.avatarPreviewUrl ?? avatar.avatarImageUrl ?? '';
      return Card(
        color: Colors.green.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Avatar ready',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (imageUrl.isNotEmpty)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 180,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const SizedBox(
                        height: 180,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.person,
                        size: 64,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                _statusMessage ??
                    'Your avatar is ready. You can use it for Try-On.',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _openTryOn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF043915),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Use Avatar in Try-On'),
              ),
            ],
          ),
        ),
      );
    }

    if (avatar != null && avatar.isFailed) {
      return Card(
        color: Colors.red.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Avatar creation failed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage ??
                    'Something went wrong. You can retry with the same photo.',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isRetrying ? null : _retryAvatar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF043915),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isRetrying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Retry Avatar Creation'),
              ),
            ],
          ),
        ),
      );
    }

    if ((avatar != null && avatar.isGenerating) ||
        _isSubmitting ||
        (_statusMessage != null &&
            (avatar == null || avatar.isGenerating))) {
      return Card(
        color: const Color(0xFF043915).withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Avatar is creating',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _statusMessage ??
                    'We will notify you when it is ready. This may take a few minutes — feel free to leave this screen.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isBusy = _isSubmitting ||
        _isRetrying ||
        (_existingAvatar?.isGenerating ?? false);
    final canCreateNew = !isBusy && !(_existingAvatar?.isGenerated ?? false);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        bottom: true,
        minimum: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
              child: ShellBackButton(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + keyboardInset),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                                'Creation runs in the background. We will notify you when your avatar is ready.',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      _buildStatusCard(),
                      const SizedBox(height: 16),

                      if (canCreateNew || _bodyImage != null) ...[
                        Text(
                          'Full Body Photo',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: isBusy
                              ? null
                              : () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (context) => SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading:
                                                const Icon(Icons.camera_alt),
                                            title: const Text('Take Photo'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _pickImage(ImageSource.camera);
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                                Icons.photo_library),
                                            title: const Text(
                                                'Choose from Gallery'),
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
                        if (_bodyImage != null) ...[
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _heightController,
                            enabled: !isBusy,
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
                              if (height == null ||
                                  height <= 0 ||
                                  height > 300) {
                                return 'Please enter a valid height (1-300 cm)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          if (!(_existingAvatar?.isGenerating ?? false) &&
                              !(_existingAvatar?.isGenerated ?? false))
                            ElevatedButton(
                              onPressed: (_isSubmitting || _bodyImage == null)
                                  ? null
                                  : _createAvatar,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF043915),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isSubmitting
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                        Text('Starting…'),
                                      ],
                                    )
                                  : const Text('Create Avatar'),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
