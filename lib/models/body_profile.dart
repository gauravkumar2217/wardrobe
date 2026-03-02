import 'package:cloud_firestore/cloud_firestore.dart';

/// Body profile model for virtual try-on
class BodyProfile {
  final String userId;
  final String? bodyImageUrl; // Original body image (max 720px width)
  final String? processedBodyImageUrl; // Processed for try-on
  final BodyLandmarks? landmarks; // ML Kit pose landmarks
  final BodyMeasurements? measurements; // Calculated measurements
  final double? userHeightCm; // User-provided height for calibration
  final DateTime? scannedAt;

  BodyProfile({
    required this.userId,
    this.bodyImageUrl,
    this.processedBodyImageUrl,
    this.landmarks,
    this.measurements,
    this.userHeightCm,
    this.scannedAt,
  });

  factory BodyProfile.fromJson(Map<String, dynamic> json, String userId) {
    return BodyProfile(
      userId: userId,
      bodyImageUrl: json['bodyImageUrl'] as String?,
      processedBodyImageUrl: json['processedBodyImageUrl'] as String?,
      landmarks: json['landmarks'] != null
          ? BodyLandmarks.fromJson(json['landmarks'] as Map<String, dynamic>)
          : null,
      measurements: json['measurements'] != null
          ? BodyMeasurements.fromJson(json['measurements'] as Map<String, dynamic>)
          : null,
      userHeightCm: (json['userHeightCm'] as num?)?.toDouble(),
      scannedAt: json['scannedAt'] != null
          ? (json['scannedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bodyImageUrl': bodyImageUrl,
      'processedBodyImageUrl': processedBodyImageUrl,
      if (landmarks != null) 'landmarks': landmarks!.toJson(),
      if (measurements != null) 'measurements': measurements!.toJson(),
      if (userHeightCm != null) 'userHeightCm': userHeightCm,
      if (scannedAt != null) 'scannedAt': Timestamp.fromDate(scannedAt!),
    };
  }

  BodyProfile copyWith({
    String? bodyImageUrl,
    String? processedBodyImageUrl,
    BodyLandmarks? landmarks,
    BodyMeasurements? measurements,
    double? userHeightCm,
    DateTime? scannedAt,
  }) {
    return BodyProfile(
      userId: userId,
      bodyImageUrl: bodyImageUrl ?? this.bodyImageUrl,
      processedBodyImageUrl: processedBodyImageUrl ?? this.processedBodyImageUrl,
      landmarks: landmarks ?? this.landmarks,
      measurements: measurements ?? this.measurements,
      userHeightCm: userHeightCm ?? this.userHeightCm,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }
}

/// Body landmarks from ML Kit Pose Detection
class BodyLandmarks {
  final Point? leftShoulder;
  final Point? rightShoulder;
  final Point? leftHip;
  final Point? rightHip;
  final Point? leftAnkle;
  final Point? rightAnkle;
  final Point? nose;

  BodyLandmarks({
    this.leftShoulder,
    this.rightShoulder,
    this.leftHip,
    this.rightHip,
    this.leftAnkle,
    this.rightAnkle,
    this.nose,
  });

  factory BodyLandmarks.fromJson(Map<String, dynamic> json) {
    return BodyLandmarks(
      leftShoulder: json['leftShoulder'] != null
          ? Point.fromJson(json['leftShoulder'] as Map<String, dynamic>)
          : null,
      rightShoulder: json['rightShoulder'] != null
          ? Point.fromJson(json['rightShoulder'] as Map<String, dynamic>)
          : null,
      leftHip: json['leftHip'] != null
          ? Point.fromJson(json['leftHip'] as Map<String, dynamic>)
          : null,
      rightHip: json['rightHip'] != null
          ? Point.fromJson(json['rightHip'] as Map<String, dynamic>)
          : null,
      leftAnkle: json['leftAnkle'] != null
          ? Point.fromJson(json['leftAnkle'] as Map<String, dynamic>)
          : null,
      rightAnkle: json['rightAnkle'] != null
          ? Point.fromJson(json['rightAnkle'] as Map<String, dynamic>)
          : null,
      nose: json['nose'] != null
          ? Point.fromJson(json['nose'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (leftShoulder != null) 'leftShoulder': leftShoulder!.toJson(),
      if (rightShoulder != null) 'rightShoulder': rightShoulder!.toJson(),
      if (leftHip != null) 'leftHip': leftHip!.toJson(),
      if (rightHip != null) 'rightHip': rightHip!.toJson(),
      if (leftAnkle != null) 'leftAnkle': leftAnkle!.toJson(),
      if (rightAnkle != null) 'rightAnkle': rightAnkle!.toJson(),
      if (nose != null) 'nose': nose!.toJson(),
    };
  }

  /// Check if all required landmarks are present
  bool get isValid {
    return leftShoulder != null &&
        rightShoulder != null &&
        leftHip != null &&
        rightHip != null &&
        leftAnkle != null &&
        rightAnkle != null &&
        nose != null;
  }
}

/// Point coordinates
class Point {
  final double x;
  final double y;

  Point({required this.x, required this.y});

  factory Point.fromJson(Map<String, dynamic> json) {
    return Point(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
    };
  }

  /// Calculate distance to another point
  double distanceTo(Point other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return (dx * dx + dy * dy);
  }
}

/// Body measurements calculated from landmarks
class BodyMeasurements {
  final double? shoulderWidthCm;
  final double? hipWidthCm;
  final double? heightCm;
  final double? cmPerPixel; // Calibration factor

  BodyMeasurements({
    this.shoulderWidthCm,
    this.hipWidthCm,
    this.heightCm,
    this.cmPerPixel,
  });

  factory BodyMeasurements.fromJson(Map<String, dynamic> json) {
    return BodyMeasurements(
      shoulderWidthCm: (json['shoulderWidthCm'] as num?)?.toDouble(),
      hipWidthCm: (json['hipWidthCm'] as num?)?.toDouble(),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      cmPerPixel: (json['cmPerPixel'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (shoulderWidthCm != null) 'shoulderWidthCm': shoulderWidthCm,
      if (hipWidthCm != null) 'hipWidthCm': hipWidthCm,
      if (heightCm != null) 'heightCm': heightCm,
      if (cmPerPixel != null) 'cmPerPixel': cmPerPixel,
    };
  }
}
