import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import '../models/body_profile.dart';
import 'image_processing_service.dart';
import 'measurement_engine.dart';

/// Body scan service using ML Kit Pose Detection (cross-platform)
/// iOS: Uses CoreML backend automatically
/// Android: Uses TensorFlow backend automatically
class BodyScanService {
  static PoseDetector? _poseDetector;

  /// Initialize pose detector (lazy initialization)
  static Future<void> initialize() async {
    try {
      if (_poseDetector != null) return;

      final options = PoseDetectorOptions(
        mode: PoseDetectionMode.single,
        model: PoseDetectionModel.accurate,
      );
      _poseDetector = PoseDetector(options: options);

      if (kDebugMode) {
        debugPrint('✅ ML Kit Pose Detector initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to initialize ML Kit Pose Detector: $e');
      }
      rethrow;
    }
  }

  /// Dispose pose detector (critical for iOS memory management)
  static Future<void> dispose() async {
    try {
      await _poseDetector?.close();
      _poseDetector = null;
      if (kDebugMode) {
        debugPrint('✅ ML Kit Pose Detector disposed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error disposing pose detector: $e');
      }
    }
  }

  /// Process image for body scan (in isolate for performance)
  static Future<BodyLandmarks?> detectPose(File imageFile) async {
    try {
      // Initialize if needed
      if (_poseDetector == null) {
        await initialize();
      }

      // Process image directly on the main isolate.
      // Using isolates with MethodChannel-based plugins (like ML Kit) can
      // cause BackgroundIsolateBinaryMessenger errors if not initialized
      // explicitly, so we keep this on the main isolate for reliability.
      final landmarks = await _processImageInIsolate(imageFile.path);

      return landmarks;
    } catch (e) {
      debugPrint('Error detecting pose: $e');
      return null;
    } finally {
      // Dispose resources after processing (critical for iOS)
      await dispose();
    }
  }

  /// Process image in isolate (static function for compute)
  static Future<BodyLandmarks?> _processImageInIsolate(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      
      // Resize image before ML processing (maxHeight: 512 for performance)
      final processedImage = await ImageProcessingService.processImageForML(imageFile);
      if (processedImage == null) {
        debugPrint('Failed to process image for ML');
        return null;
      }

      // Initialize pose detector in isolate
      final options = PoseDetectorOptions(
        mode: PoseDetectionMode.single,
        model: PoseDetectionModel.accurate,
      );
      final poseDetector = PoseDetector(options: options);

      // Create input image
      final inputImage = InputImage.fromFilePath(processedImage.path);

      // Detect poses
      final poses = await poseDetector.processImage(inputImage);

      // Dispose pose detector
      await poseDetector.close();

      if (poses.isEmpty) {
        debugPrint('No poses detected');
        return null;
      }

      // Use first valid pose
      final pose = poses.first;

      // Extract required landmarks
      final landmarks = _extractLandmarks(pose);

      if (!landmarks.isValid) {
        debugPrint('Invalid landmarks extracted');
        return null;
      }

      return landmarks;
    } catch (e) {
      debugPrint('Error in isolate processing: $e');
      return null;
    }
  }

  /// Extract required landmarks from pose
  static BodyLandmarks _extractLandmarks(Pose pose) {
    Point? leftShoulder;
    Point? rightShoulder;
    Point? leftHip;
    Point? rightHip;
    Point? leftAnkle;
    Point? rightAnkle;
    Point? nose;

    // Extract landmarks
    for (final landmark in pose.landmarks.values) {
      switch (landmark.type) {
        case PoseLandmarkType.leftShoulder:
          leftShoulder = Point(x: landmark.x, y: landmark.y);
          break;
        case PoseLandmarkType.rightShoulder:
          rightShoulder = Point(x: landmark.x, y: landmark.y);
          break;
        case PoseLandmarkType.leftHip:
          leftHip = Point(x: landmark.x, y: landmark.y);
          break;
        case PoseLandmarkType.rightHip:
          rightHip = Point(x: landmark.x, y: landmark.y);
          break;
        case PoseLandmarkType.leftAnkle:
          leftAnkle = Point(x: landmark.x, y: landmark.y);
          break;
        case PoseLandmarkType.rightAnkle:
          rightAnkle = Point(x: landmark.x, y: landmark.y);
          break;
        case PoseLandmarkType.nose:
          nose = Point(x: landmark.x, y: landmark.y);
          break;
        default:
          break;
      }
    }

    return BodyLandmarks(
      leftShoulder: leftShoulder,
      rightShoulder: rightShoulder,
      leftHip: leftHip,
      rightHip: rightHip,
      leftAnkle: leftAnkle,
      rightAnkle: rightAnkle,
      nose: nose,
    );
  }

  /// Complete body scan process
  /// Returns BodyProfile with landmarks and measurements
  static Future<BodyProfile?> scanBody({
    required String userId,
    required File imageFile,
    required double userHeightCm,
  }) async {
    try {
      // Step 1: Process image for body scan (HEIC conversion, resize, compress)
      final processedImage = await ImageProcessingService.processImageForBodyScan(imageFile);
      if (processedImage == null) {
        debugPrint('Failed to process image for body scan');
        return null;
      }

      // Step 2: Detect pose (in isolate)
      final landmarks = await detectPose(processedImage);
      if (landmarks == null || !landmarks.isValid) {
        debugPrint('Failed to detect valid pose');
        return null;
      }

      // Step 3: Calculate measurements
      final measurements = MeasurementEngine.calculateMeasurements(
        landmarks: landmarks,
        userHeightCm: userHeightCm,
      );

      // Step 4: Create body profile
      return BodyProfile(
        userId: userId,
        bodyImageUrl: null, // Will be set after upload
        processedBodyImageUrl: null, // Will be set after processing
        landmarks: landmarks,
        measurements: measurements,
        userHeightCm: userHeightCm,
        scannedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error in body scan: $e');
      return null;
    }
  }
}
