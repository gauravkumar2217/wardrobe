import 'package:cloud_firestore/cloud_firestore.dart';

/// Advanced avatar model with 3 view URLs, pose keypoints, and generation status
/// Extends the basic Avatar model with AI generation features
class AvatarAdvanced {
  final String userId;
  
  // Input images (6 photos)
  final String? faceImageLeftUrl;
  final String? faceImageCenterUrl;
  final String? faceImageRightUrl;
  final String? bodyImageLeftUrl;
  final String? bodyImageCenterUrl;
  final String? bodyImageRightUrl;
  
  // Generated avatar views (3 angles)
  final String? avatarFrontUrl; // Front view with transparent background
  final String? avatarLeftUrl;  // Left side view
  final String? avatarRightUrl; // Right side view
  
  // Body measurements (extended)
  final double? userHeightCm;
  final ExtendedMeasurements? measurements;
  
  // Pose keypoints (for clothing alignment)
  final PoseKeypoints? poseKeypoints;
  
  // Generation status
  final AvatarGenerationStatus generationStatus;
  final String? generationJobId;
  final String? generationError;
  
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AvatarAdvanced({
    required this.userId,
    this.faceImageLeftUrl,
    this.faceImageCenterUrl,
    this.faceImageRightUrl,
    this.bodyImageLeftUrl,
    this.bodyImageCenterUrl,
    this.bodyImageRightUrl,
    this.avatarFrontUrl,
    this.avatarLeftUrl,
    this.avatarRightUrl,
    this.userHeightCm,
    this.measurements,
    this.poseKeypoints,
    this.generationStatus = AvatarGenerationStatus.pending,
    this.generationJobId,
    this.generationError,
    this.createdAt,
    this.updatedAt,
  });

  factory AvatarAdvanced.fromJson(Map<String, dynamic> json, String userId) {
    return AvatarAdvanced(
      userId: userId,
      faceImageLeftUrl: json['faceImageLeftUrl'] as String?,
      faceImageCenterUrl: json['faceImageCenterUrl'] as String?,
      faceImageRightUrl: json['faceImageRightUrl'] as String?,
      bodyImageLeftUrl: json['bodyImageLeftUrl'] as String?,
      bodyImageCenterUrl: json['bodyImageCenterUrl'] as String?,
      bodyImageRightUrl: json['bodyImageRightUrl'] as String?,
      avatarFrontUrl: json['avatarFrontUrl'] as String?,
      avatarLeftUrl: json['avatarLeftUrl'] as String?,
      avatarRightUrl: json['avatarRightUrl'] as String?,
      userHeightCm: (json['userHeightCm'] as num?)?.toDouble(),
      measurements: json['measurements'] != null
          ? ExtendedMeasurements.fromJson(json['measurements'] as Map<String, dynamic>)
          : null,
      poseKeypoints: json['poseKeypoints'] != null
          ? PoseKeypoints.fromJson(json['poseKeypoints'] as Map<String, dynamic>)
          : null,
      generationStatus: AvatarGenerationStatus.fromString(
        json['generationStatus'] as String? ?? 'pending',
      ),
      generationJobId: json['generationJobId'] as String?,
      generationError: json['generationError'] as String?,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (faceImageLeftUrl != null) 'faceImageLeftUrl': faceImageLeftUrl,
      if (faceImageCenterUrl != null) 'faceImageCenterUrl': faceImageCenterUrl,
      if (faceImageRightUrl != null) 'faceImageRightUrl': faceImageRightUrl,
      if (bodyImageLeftUrl != null) 'bodyImageLeftUrl': bodyImageLeftUrl,
      if (bodyImageCenterUrl != null) 'bodyImageCenterUrl': bodyImageCenterUrl,
      if (bodyImageRightUrl != null) 'bodyImageRightUrl': bodyImageRightUrl,
      if (avatarFrontUrl != null) 'avatarFrontUrl': avatarFrontUrl,
      if (avatarLeftUrl != null) 'avatarLeftUrl': avatarLeftUrl,
      if (avatarRightUrl != null) 'avatarRightUrl': avatarRightUrl,
      if (userHeightCm != null) 'userHeightCm': userHeightCm,
      if (measurements != null) 'measurements': measurements!.toJson(),
      if (poseKeypoints != null) 'poseKeypoints': poseKeypoints!.toJson(),
      'generationStatus': generationStatus.value,
      if (generationJobId != null) 'generationJobId': generationJobId,
      if (generationError != null) 'generationError': generationError,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  AvatarAdvanced copyWith({
    String? faceImageLeftUrl,
    String? faceImageCenterUrl,
    String? faceImageRightUrl,
    String? bodyImageLeftUrl,
    String? bodyImageCenterUrl,
    String? bodyImageRightUrl,
    String? avatarFrontUrl,
    String? avatarLeftUrl,
    String? avatarRightUrl,
    double? userHeightCm,
    ExtendedMeasurements? measurements,
    PoseKeypoints? poseKeypoints,
    AvatarGenerationStatus? generationStatus,
    String? generationJobId,
    String? generationError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AvatarAdvanced(
      userId: userId,
      faceImageLeftUrl: faceImageLeftUrl ?? this.faceImageLeftUrl,
      faceImageCenterUrl: faceImageCenterUrl ?? this.faceImageCenterUrl,
      faceImageRightUrl: faceImageRightUrl ?? this.faceImageRightUrl,
      bodyImageLeftUrl: bodyImageLeftUrl ?? this.bodyImageLeftUrl,
      bodyImageCenterUrl: bodyImageCenterUrl ?? this.bodyImageCenterUrl,
      bodyImageRightUrl: bodyImageRightUrl ?? this.bodyImageRightUrl,
      avatarFrontUrl: avatarFrontUrl ?? this.avatarFrontUrl,
      avatarLeftUrl: avatarLeftUrl ?? this.avatarLeftUrl,
      avatarRightUrl: avatarRightUrl ?? this.avatarRightUrl,
      userHeightCm: userHeightCm ?? this.userHeightCm,
      measurements: measurements ?? this.measurements,
      poseKeypoints: poseKeypoints ?? this.poseKeypoints,
      generationStatus: generationStatus ?? this.generationStatus,
      generationJobId: generationJobId ?? this.generationJobId,
      generationError: generationError ?? this.generationError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if all required images are captured
  bool get hasAllImages {
    return faceImageLeftUrl != null &&
        faceImageCenterUrl != null &&
        faceImageRightUrl != null &&
        bodyImageLeftUrl != null &&
        bodyImageCenterUrl != null &&
        bodyImageRightUrl != null;
  }

  /// Check if avatar is fully generated
  bool get isGenerated {
    return generationStatus == AvatarGenerationStatus.completed &&
        avatarFrontUrl != null &&
        avatarLeftUrl != null &&
        avatarRightUrl != null;
  }

  /// Get avatar URL for specific view angle
  String? getAvatarUrlForAngle(String angle) {
    switch (angle.toLowerCase()) {
      case 'front':
      case 'center':
        return avatarFrontUrl;
      case 'left':
        return avatarLeftUrl;
      case 'right':
        return avatarRightUrl;
      default:
        return avatarFrontUrl;
    }
  }
}

/// Extended body measurements with chest and waist
class ExtendedMeasurements {
  final double? height;
  final double? shoulderWidth;
  final double? chest;
  final double? waist;
  final double? hips;
  final double? cmPerPixel;

  ExtendedMeasurements({
    this.height,
    this.shoulderWidth,
    this.chest,
    this.waist,
    this.hips,
    this.cmPerPixel,
  });

  factory ExtendedMeasurements.fromJson(Map<String, dynamic> json) {
    return ExtendedMeasurements(
      height: (json['height'] as num?)?.toDouble(),
      shoulderWidth: (json['shoulderWidth'] as num?)?.toDouble(),
      chest: (json['chest'] as num?)?.toDouble(),
      waist: (json['waist'] as num?)?.toDouble(),
      hips: (json['hips'] as num?)?.toDouble(),
      cmPerPixel: (json['cmPerPixel'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (height != null) 'height': height,
      if (shoulderWidth != null) 'shoulderWidth': shoulderWidth,
      if (chest != null) 'chest': chest,
      if (waist != null) 'waist': waist,
      if (hips != null) 'hips': hips,
      if (cmPerPixel != null) 'cmPerPixel': cmPerPixel,
    };
  }
}

/// Pose keypoints for clothing alignment
class PoseKeypoints {
  final List<Point2D>? shoulders;
  final List<Point2D>? hips;
  final List<Point2D>? ankles;
  final List<Point2D>? elbows;
  final List<Point2D>? wrists;
  final List<Point2D>? knees;

  PoseKeypoints({
    this.shoulders,
    this.hips,
    this.ankles,
    this.elbows,
    this.wrists,
    this.knees,
  });

  factory PoseKeypoints.fromJson(Map<String, dynamic> json) {
    return PoseKeypoints(
      shoulders: json['shoulders'] != null
          ? (json['shoulders'] as List)
              .map((e) => Point2D.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      hips: json['hips'] != null
          ? (json['hips'] as List)
              .map((e) => Point2D.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      ankles: json['ankles'] != null
          ? (json['ankles'] as List)
              .map((e) => Point2D.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      elbows: json['elbows'] != null
          ? (json['elbows'] as List)
              .map((e) => Point2D.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      wrists: json['wrists'] != null
          ? (json['wrists'] as List)
              .map((e) => Point2D.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      knees: json['knees'] != null
          ? (json['knees'] as List)
              .map((e) => Point2D.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (shoulders != null)
        'shoulders': shoulders!.map((e) => e.toJson()).toList(),
      if (hips != null) 'hips': hips!.map((e) => e.toJson()).toList(),
      if (ankles != null) 'ankles': ankles!.map((e) => e.toJson()).toList(),
      if (elbows != null) 'elbows': elbows!.map((e) => e.toJson()).toList(),
      if (wrists != null) 'wrists': wrists!.map((e) => e.toJson()).toList(),
      if (knees != null) 'knees': knees!.map((e) => e.toJson()).toList(),
    };
  }
}

/// 2D point for keypoints
class Point2D {
  final double x;
  final double y;

  Point2D({required this.x, required this.y});

  factory Point2D.fromJson(Map<String, dynamic> json) {
    return Point2D(
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
}

/// Avatar generation status
enum AvatarGenerationStatus {
  pending,
  processing,
  completed,
  failed;

  String get value {
    switch (this) {
      case AvatarGenerationStatus.pending:
        return 'pending';
      case AvatarGenerationStatus.processing:
        return 'processing';
      case AvatarGenerationStatus.completed:
        return 'completed';
      case AvatarGenerationStatus.failed:
        return 'failed';
    }
  }

  static AvatarGenerationStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return AvatarGenerationStatus.pending;
      case 'processing':
        return AvatarGenerationStatus.processing;
      case 'completed':
        return AvatarGenerationStatus.completed;
      case 'failed':
        return AvatarGenerationStatus.failed;
      default:
        return AvatarGenerationStatus.pending;
    }
  }
}
