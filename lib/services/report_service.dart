import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/report.dart';
import 'laravel_api_client.dart';

/// Reports via Laravel API (MySQL). No Firestore.
class ReportService {
  static Future<String> createReport({
    required String reporterId,
    required String reportedUserId,
    required ReportContentType contentType,
    String? contentId,
    required String reason,
    String? description,
  }) async {
    final body = await LaravelApiClient.postJson(ApiConfig.reports, {
      'reported_user_id': reportedUserId,
      'content_type': contentType.toString(),
      if (contentId != null) 'content_id': contentId,
      'reason': reason,
      if (description != null) 'description': description,
    });
    final data = LaravelApiClient.extractData(body);
    if (data is Map && data['id'] != null) {
      final id = data['id'].toString();
      debugPrint('Report created via API: $id');
      return id;
    }
    throw Exception(body['message']?.toString() ?? 'Failed to create report');
  }

  static Future<List<Report>> getReportsForUser(String userId) async {
    debugPrint('getReportsForUser: admin-only; not on mobile API');
    return [];
  }

  static Future<List<Report>> getPendingReports() async {
    debugPrint('getPendingReports: admin-only; not on mobile API');
    return [];
  }

  static Future<void> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    String? reviewedBy,
  }) async {
    debugPrint('updateReportStatus: admin-only; not on mobile API');
  }

  static Future<bool> hasUserReported({
    required String reporterId,
    required String reportedUserId,
    ReportContentType? contentType,
    String? contentId,
  }) async {
    // Client-side duplicate check not required for MVP.
    return false;
  }

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
