import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/report.dart';

/// Service for handling user reports of objectionable content
class ReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a report for objectionable content or user
  static Future<String> createReport({
    required String reporterId,
    required String reportedUserId,
    required ReportContentType contentType,
    String? contentId,
    required String reason,
    String? description,
  }) async {
    try {
      final reportId = _firestore.collection('reports').doc().id;
      final now = DateTime.now();

      final report = Report(
        id: reportId,
        reporterId: reporterId,
        reportedUserId: reportedUserId,
        contentType: contentType,
        contentId: contentId,
        reason: reason,
        description: description,
        status: ReportStatus.pending,
        createdAt: now,
      );

      // Save report
      await _firestore
          .collection('reports')
          .doc(reportId)
          .set(report.toJson());

      // Trigger Cloud Function to send email notification
      // This will be handled by Firebase Functions
      debugPrint('Report created: $reportId');

      return reportId;
    } catch (e) {
      debugPrint('Failed to create report: $e');
      rethrow;
    }
  }

  /// Get reports for a specific user (admin function)
  static Future<List<Report>> getReportsForUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('reportedUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Report.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Failed to get reports for user: $e');
      return [];
    }
  }

  /// Get pending reports (admin function)
  static Future<List<Report>> getPendingReports() async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => Report.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Failed to get pending reports: $e');
      return [];
    }
  }

  /// Update report status (admin function)
  static Future<void> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    String? reviewedBy,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status.toString(),
        'reviewedAt': FieldValue.serverTimestamp(),
      };

      if (reviewedBy != null) {
        updates['reviewedBy'] = reviewedBy;
      }

      await _firestore.collection('reports').doc(reportId).update(updates);
    } catch (e) {
      debugPrint('Failed to update report status: $e');
      rethrow;
    }
  }

  /// Check if user has already reported this content
  static Future<bool> hasUserReported({
    required String reporterId,
    required String reportedUserId,
    ReportContentType? contentType,
    String? contentId,
  }) async {
    try {
      Query query = _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: reporterId)
          .where('reportedUserId', isEqualTo: reportedUserId);

      if (contentType != null) {
        query = query.where('contentType', isEqualTo: contentType.toString());
      }

      if (contentId != null) {
        query = query.where('contentId', isEqualTo: contentId);
      }

      final snapshot = await query.limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Failed to check if user reported: $e');
      return false;
    }
  }

  /// Get report reasons (predefined list)
  static List<String> getReportReasons() {
    return [
      'Harassment or Bullying',
      'Spam or Scam',
      'Inappropriate Content',
      'Hate Speech',
      'Violence or Threats',
      'Sexual Content',
      'Impersonation',
      'Other',
    ];
  }
}
