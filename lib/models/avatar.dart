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
  final String? errorMessage;

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
    this.errorMessage,
    this.userHeightCm,
    this.measurements,
    this.createdAt,
    this.updatedAt,
  });

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) return DateTime.parse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String && value.isNotEmpty) return double.tryParse(value);
    return null;
  }

  factory Avatar.fromJson(Map<String, dynamic> json, String userId) {
    return Avatar(
      userId: userId,
      bodyImageUrl:
          json['body_image_url'] as String? ?? json['bodyImageUrl'] as String?,
      avatarImageUrl: json['avatar_image_url'] as String? ??
          json['avatarImageUrl'] as String?,
      avatarPreviewUrl: json['avatar_preview_url'] as String? ??
          json['avatarPreviewUrl'] as String?,
      poseLandmarks: json['pose_landmarks'] as Map<String, dynamic>? ??
          json['poseLandmarks'] as Map<String, dynamic>?,
      generationStatus: json['generation_status'] as String? ??
          json['generationStatus'] as String?,
      generationJobId: json['generation_job_id']?.toString() ??
          json['generationJobId']?.toString() ??
          json['id']?.toString(),
      errorMessage: json['error_message'] as String? ??
          json['errorMessage'] as String?,
      userHeightCm: _parseDouble(json['user_height_cm']) ??
          _parseDouble(json['userHeightCm']),
      measurements: json['measurements'] != null
          ? BodyMeasurements.fromJson(
              json['measurements'] as Map<String, dynamic>)
          : null,
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDate(json['updated_at'] ?? json['updatedAt']),
    );
  }

  factory Avatar.fromApiJson(Map<String, dynamic> json, String userId) {
    return Avatar.fromJson(json, userId);
  }

  Map<String, dynamic> toJson() {
    return {
      if (bodyImageUrl != null) 'bodyImageUrl': bodyImageUrl,
      if (avatarImageUrl != null) 'avatarImageUrl': avatarImageUrl,
      if (avatarPreviewUrl != null) 'avatarPreviewUrl': avatarPreviewUrl,
      if (poseLandmarks != null) 'poseLandmarks': poseLandmarks,
      if (generationStatus != null) 'generationStatus': generationStatus,
      if (generationJobId != null) 'generationJobId': generationJobId,
      if (errorMessage != null) 'errorMessage': errorMessage,
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
    String? errorMessage,
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
      errorMessage: errorMessage ?? this.errorMessage,
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
    final url = avatarImageUrl?.trim();
    if (url == null || url.isEmpty) return false;
    if (isGenerating || isFailed) return false;
    return true;
  }

  /// Check if generation is in progress
  bool get isGenerating {
    return generationStatus == 'pending' || generationStatus == 'processing';
  }

  bool get isFailed {
    return generationStatus == 'failed';
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

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String && value.isNotEmpty) return double.tryParse(value);
    return null;
  }

  factory BodyMeasurements.fromJson(Map<String, dynamic> json) {
    return BodyMeasurements(
      shoulderWidthCm: _parseDouble(json['shoulder_width_cm']) ??
          _parseDouble(json['shoulderWidthCm']),
      hipWidthCm: _parseDouble(json['hip_width_cm']) ??
          _parseDouble(json['hipWidthCm']),
      heightCm: _parseDouble(json['height_cm']) ??
          _parseDouble(json['heightCm']),
      cmPerPixel: _parseDouble(json['cm_per_pixel']) ??
          _parseDouble(json['cmPerPixel']),
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
