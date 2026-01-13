import 'package:cloud_firestore/cloud_firestore.dart';

/// Report model for flagging objectionable content or users
class Report {
  final String id;
  final String reporterId;
  final String reportedUserId;
  final ReportContentType contentType;
  final String? contentId;
  final String reason;
  final String? description;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  Report({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    required this.contentType,
    this.contentId,
    required this.reason,
    this.description,
    this.status = ReportStatus.pending,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory Report.fromJson(Map<String, dynamic> json, String id) {
    return Report(
      id: id,
      reporterId: json['reporterId'] as String,
      reportedUserId: json['reportedUserId'] as String,
      contentType: ReportContentType.fromString(json['contentType'] as String),
      contentId: json['contentId'] as String?,
      reason: json['reason'] as String,
      description: json['description'] as String?,
      status: ReportStatus.fromString(json['status'] as String? ?? 'pending'),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      reviewedAt: json['reviewedAt'] != null
          ? (json['reviewedAt'] as Timestamp).toDate()
          : null,
      reviewedBy: json['reviewedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'contentType': contentType.toString(),
      if (contentId != null) 'contentId': contentId,
      'reason': reason,
      if (description != null) 'description': description,
      'status': status.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
    };
  }
}

enum ReportContentType {
  comment,
  message,
  user;

  static ReportContentType fromString(String value) {
    switch (value) {
      case 'comment':
        return ReportContentType.comment;
      case 'message':
        return ReportContentType.message;
      case 'user':
        return ReportContentType.user;
      default:
        return ReportContentType.user;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ReportContentType.comment:
        return 'comment';
      case ReportContentType.message:
        return 'message';
      case ReportContentType.user:
        return 'user';
    }
  }
}

enum ReportStatus {
  pending,
  reviewed,
  resolved,
  dismissed;

  static ReportStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return ReportStatus.pending;
      case 'reviewed':
        return ReportStatus.reviewed;
      case 'resolved':
        return ReportStatus.resolved;
      case 'dismissed':
        return ReportStatus.dismissed;
      default:
        return ReportStatus.pending;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ReportStatus.pending:
        return 'pending';
      case ReportStatus.reviewed:
        return 'reviewed';
      case ReportStatus.resolved:
        return 'resolved';
      case ReportStatus.dismissed:
        return 'dismissed';
    }
  }
}
