import 'package:flutter/foundation.dart';
import '../models/body_profile.dart';

/// Measurement engine for calculating body measurements from landmarks
/// Platform independent - pixel calculations are the same on both platforms
class MeasurementEngine {
  /// Calculate pixel distances from landmarks
  static double _calculatePixelDistance(Point? point1, Point? point2) {
    if (point1 == null || point2 == null) return 0.0;
    
    final dx = point1.x - point2.x;
    final dy = point1.y - point2.y;
    return (dx * dx + dy * dy);
  }

  /// Calculate shoulder width in pixels
  static double calculateShoulderWidthPx(BodyLandmarks landmarks) {
    return _calculatePixelDistance(
      landmarks.leftShoulder,
      landmarks.rightShoulder,
    );
  }

  /// Calculate hip width in pixels
  static double calculateHipWidthPx(BodyLandmarks landmarks) {
    return _calculatePixelDistance(
      landmarks.leftHip,
      landmarks.rightHip,
    );
  }

  /// Calculate height in pixels (from nose to average ankle position)
  static double calculateHeightPx(BodyLandmarks landmarks) {
    if (landmarks.nose == null || 
        landmarks.leftAnkle == null || 
        landmarks.rightAnkle == null) {
      return 0.0;
    }

    // Calculate average ankle position
    final avgAnkleX = (landmarks.leftAnkle!.x + landmarks.rightAnkle!.x) / 2;
    final avgAnkleY = (landmarks.leftAnkle!.y + landmarks.rightAnkle!.y) / 2;
    final avgAnkle = Point(x: avgAnkleX, y: avgAnkleY);

    return _calculatePixelDistance(landmarks.nose, avgAnkle);
  }

  /// Calculate cm per pixel calibration factor
  /// This is mandatory for accuracy - requires user-provided height
  static double calculateCmPerPixel(double heightPx, double userHeightCm) {
    if (heightPx <= 0 || userHeightCm <= 0) {
      return 0.0;
    }
    return userHeightCm / heightPx;
  }

  /// Calculate real-world measurements from pixel measurements
  static BodyMeasurements calculateMeasurements({
    required BodyLandmarks landmarks,
    required double userHeightCm,
  }) {
    // Calculate pixel measurements
    final shoulderWidthPx = calculateShoulderWidthPx(landmarks);
    final hipWidthPx = calculateHipWidthPx(landmarks);
    final heightPx = calculateHeightPx(landmarks);

    if (heightPx <= 0) {
      debugPrint('Invalid height pixels: $heightPx');
      return BodyMeasurements();
    }

    // Calculate calibration factor
    final cmPerPixel = calculateCmPerPixel(heightPx, userHeightCm);

    if (cmPerPixel <= 0) {
      debugPrint('Invalid cm per pixel: $cmPerPixel');
      return BodyMeasurements(cmPerPixel: 0.0);
    }

    // Convert pixel measurements to real-world measurements
    final shoulderWidthCm = shoulderWidthPx * cmPerPixel;
    final hipWidthCm = hipWidthPx * cmPerPixel;

    return BodyMeasurements(
      shoulderWidthCm: shoulderWidthCm,
      hipWidthCm: hipWidthCm,
      heightCm: userHeightCm,
      cmPerPixel: cmPerPixel,
    );
  }

  /// Validate that all required landmarks are present
  static bool validateLandmarks(BodyLandmarks landmarks) {
    return landmarks.isValid;
  }
}
