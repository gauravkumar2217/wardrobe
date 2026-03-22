import 'package:cloud_firestore/cloud_firestore.dart';

/// Avatar model for user avatar creation
/// Uses a single full-body photo to generate a clean 2D transparent PNG avatar
class Avatar {
  final String userId;

  // Original body image (single photo)
  final String? bodyImageUrl; // Original uploaded full-body photo

  // Generated 2D avatar (transparent PNG)
  final String? avatarImageUrl; // Clean avatar with transparent background
  final String? avatarPreviewUrl; // Preview/thumbnail of avatar

  // Pose landmarks from MediaPipe (cached for try-on)
  final Map<String, dynamic>? poseLandmarks; // Cached MediaPipe pose landmarks
  
  // Generation status
  final String? generationStatus; // 'pending', 'processing', 'completed', 'failed'
  final String? generationJobId; // Backend job ID for tracking

  // Body measurements (for try-on)
  final double? userHeightCm;
  final BodyMeasurements? measurements;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Avatar({
    required this.userId,
    this.bodyImageUrl,
    this.avatarImageUrl,
    this.avatarPreviewUrl,
    this.poseLandmarks,
    this.generationStatus,
    this.generationJobId,
    this.userHeightCm,
    this.measurements,
    this.createdAt,
    this.updatedAt,
  });

  factory Avatar.fromJson(Map<String, dynamic> json, String userId) {
    return Avatar(
      userId: userId,
      bodyImageUrl: json['bodyImageUrl'] as String?,
      avatarImageUrl: json['avatarImageUrl'] as String?,
      avatarPreviewUrl: json['avatarPreviewUrl'] as String?,
      poseLandmarks: json['poseLandmarks'] as Map<String, dynamic>?,
      generationStatus: json['generationStatus'] as String?,
      generationJobId: json['generationJobId'] as String?,
      userHeightCm: (json['userHeightCm'] as num?)?.toDouble(),
      measurements: json['measurements'] != null
          ? BodyMeasurements.fromJson(
              json['measurements'] as Map<String, dynamic>)
          : null,
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
      if (bodyImageUrl != null) 'bodyImageUrl': bodyImageUrl,
      if (avatarImageUrl != null) 'avatarImageUrl': avatarImageUrl,
      if (avatarPreviewUrl != null) 'avatarPreviewUrl': avatarPreviewUrl,
      if (poseLandmarks != null) 'poseLandmarks': poseLandmarks,
      if (generationStatus != null) 'generationStatus': generationStatus,
      if (generationJobId != null) 'generationJobId': generationJobId,
      if (userHeightCm != null) 'userHeightCm': userHeightCm,
      if (measurements != null) 'measurements': measurements!.toJson(),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  Avatar copyWith({
    String? bodyImageUrl,
    String? avatarImageUrl,
    String? avatarPreviewUrl,
    Map<String, dynamic>? poseLandmarks,
    String? generationStatus,
    String? generationJobId,
    double? userHeightCm,
    BodyMeasurements? measurements,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Avatar(
      userId: userId,
      bodyImageUrl: bodyImageUrl ?? this.bodyImageUrl,
      avatarImageUrl: avatarImageUrl ?? this.avatarImageUrl,
      avatarPreviewUrl: avatarPreviewUrl ?? this.avatarPreviewUrl,
      poseLandmarks: poseLandmarks ?? this.poseLandmarks,
      generationStatus: generationStatus ?? this.generationStatus,
      generationJobId: generationJobId ?? this.generationJobId,
      userHeightCm: userHeightCm ?? this.userHeightCm,
      measurements: measurements ?? this.measurements,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if body image is uploaded
  bool get hasBodyImage {
    return bodyImageUrl != null;
  }

  /// Check if avatar is generated (2D transparent PNG)
  bool get isGenerated {
    return avatarImageUrl != null;
  }

  /// Check if generation is in progress
  bool get isGenerating {
    return generationStatus == 'pending' || generationStatus == 'processing';
  }
}

/// Body measurements for try-on (reused from body_profile)
class BodyMeasurements {
  final double? shoulderWidthCm;
  final double? hipWidthCm;
  final double? heightCm;
  final double? cmPerPixel;

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
