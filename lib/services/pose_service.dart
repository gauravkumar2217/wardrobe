import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import '../models/avatar_advanced.dart';
import 'image_processing_service.dart';
import 'body_scan_service.dart';

/// Service for client-side pose detection and validation
/// Uses MediaPipe via ML Kit for pose keypoint extraction
class PoseService {
  static PoseDetector? _poseDetector;

  /// Initialize pose detector
  static Future<void> initialize() async {
    try {
      if (_poseDetector != null) return;

      final options = PoseDetectorOptions(
        mode: PoseDetectionMode.single,
        model: PoseDetectionModel.accurate,
      );
      _poseDetector = PoseDetector(options: options);

      if (kDebugMode) {
        debugPrint('✅ Pose Service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to initialize Pose Service: $e');
      }
      rethrow;
    }
  }

  /// Dispose pose detector
  static Future<void> dispose() async {
    try {
      await _poseDetector?.close();
      _poseDetector = null;
      if (kDebugMode) {
        debugPrint('✅ Pose Service disposed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error disposing pose detector: $e');
      }
    }
  }

  /// Detect pose and extract keypoints from image
  static Future<PoseKeypoints?> detectPoseKeypoints(File imageFile) async {
    try {
      if (_poseDetector == null) {
        await initialize();
      }

      // Process image for ML
      final processedImage = await ImageProcessingService.processImageForML(imageFile);
      if (processedImage == null) {
        debugPrint('Failed to process image for pose detection');
        return null;
      }

      // Create input image
      final inputImage = InputImage.fromFilePath(processedImage.path);

      // Detect poses
      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isEmpty) {
        debugPrint('No poses detected');
        return null;
      }

      // Use first valid pose
      final pose = poses.first;

      // Extract keypoints
      return _extractKeypoints(pose);
    } catch (e) {
      debugPrint('Error detecting pose keypoints: $e');
      return null;
    } finally {
      await dispose();
    }
  }

  /// Extract keypoints from pose
  static PoseKeypoints _extractKeypoints(Pose pose) {
    final shoulders = <Point2D>[];
    final hips = <Point2D>[];
    final ankles = <Point2D>[];
    final elbows = <Point2D>[];
    final wrists = <Point2D>[];
    final knees = <Point2D>[];

    for (final landmark in pose.landmarks.values) {
      final point = Point2D(x: landmark.x, y: landmark.y);
      
      switch (landmark.type) {
        case PoseLandmarkType.leftShoulder:
        case PoseLandmarkType.rightShoulder:
          shoulders.add(point);
          break;
        case PoseLandmarkType.leftHip:
        case PoseLandmarkType.rightHip:
          hips.add(point);
          break;
        case PoseLandmarkType.leftAnkle:
        case PoseLandmarkType.rightAnkle:
          ankles.add(point);
          break;
        case PoseLandmarkType.leftElbow:
        case PoseLandmarkType.rightElbow:
          elbows.add(point);
          break;
        case PoseLandmarkType.leftWrist:
        case PoseLandmarkType.rightWrist:
          wrists.add(point);
          break;
        case PoseLandmarkType.leftKnee:
        case PoseLandmarkType.rightKnee:
          knees.add(point);
          break;
        default:
          break;
      }
    }

    return PoseKeypoints(
      shoulders: shoulders.isNotEmpty ? shoulders : null,
      hips: hips.isNotEmpty ? hips : null,
      ankles: ankles.isNotEmpty ? ankles : null,
      elbows: elbows.isNotEmpty ? elbows : null,
      wrists: wrists.isNotEmpty ? wrists : null,
      knees: knees.isNotEmpty ? knees : null,
    );
  }

  /// Validate pose quality (for avatar generation)
  /// Returns true if pose is suitable for avatar generation
  static bool validatePoseQuality(PoseKeypoints keypoints) {
    // Check if essential keypoints are present
    if (keypoints.shoulders == null || keypoints.shoulders!.length < 2) {
      return false; // Need both shoulders
    }

    if (keypoints.hips == null || keypoints.hips!.length < 2) {
      return false; // Need both hips
    }

    if (keypoints.ankles == null || keypoints.ankles!.length < 2) {
      return false; // Need both ankles
    }

    // Check if body is reasonably upright
    final leftShoulder = keypoints.shoulders!.first;
    final rightShoulder = keypoints.shoulders!.length > 1 
        ? keypoints.shoulders![1] 
        : leftShoulder;
    
    final leftHip = keypoints.hips!.first;
    final rightHip = keypoints.hips!.length > 1 
        ? keypoints.hips![1] 
        : leftHip;

    // Shoulders should be roughly level (within 10% of image height)
    final shoulderDiff = (leftShoulder.y - rightShoulder.y).abs();
    final imageHeight = 512.0; // Approximate from processed image
    if (shoulderDiff > imageHeight * 0.1) {
      return false; // Shoulders not level
    }

    // Hips should be roughly level
    final hipDiff = (leftHip.y - rightHip.y).abs();
    if (hipDiff > imageHeight * 0.1) {
      return false; // Hips not level
    }

    return true;
  }

  /// Check if pose is in standard T-pose or A-pose
  /// Returns 't-pose', 'a-pose', or 'other'
  static String detectPoseType(PoseKeypoints keypoints) {
    if (keypoints.shoulders == null || 
        keypoints.elbows == null || 
        keypoints.wrists == null) {
      return 'other';
    }

    // Check if arms are extended (T-pose)
    // In T-pose, wrists should be roughly at shoulder level and far from body
    final leftShoulder = keypoints.shoulders!.first;
    final rightShoulder = keypoints.shoulders!.length > 1 
        ? keypoints.shoulders![1] 
        : leftShoulder;

    if (keypoints.wrists!.length >= 2) {
      final leftWrist = keypoints.wrists!.first;
      final rightWrist = keypoints.wrists![1];
      
      // Check if wrists are at similar Y level as shoulders
      final shoulderY = (leftShoulder.y + rightShoulder.y) / 2;
      final wristY = (leftWrist.y + rightWrist.y) / 2;
      final yDiff = (shoulderY - wristY).abs();
      
      if (yDiff < 50) { // Within 50 pixels
        return 't-pose';
      }
    }

    // Check if arms are slightly away from body (A-pose)
    if (keypoints.elbows!.length >= 2) {
      final leftElbow = keypoints.elbows!.first;
      final rightElbow = keypoints.elbows![1];
      
      // Elbows should be slightly away from shoulders
      final shoulderX = (leftShoulder.x + rightShoulder.x) / 2;
      final elbowX = (leftElbow.x + rightElbow.x) / 2;
      final xDiff = (shoulderX - elbowX).abs();
      
      if (xDiff > 30 && xDiff < 100) { // Moderate distance
        return 'a-pose';
      }
    }

    return 'other';
  }
}
