import 'package:cloud_firestore/cloud_firestore.dart';

/// EULA Acceptance model to track user acceptance of Terms & Conditions
class EulaAcceptance {
  final String id;
  final String userId;
  final String version;
  final DateTime acceptedAt;
  final String? ipAddress;

  EulaAcceptance({
    required this.id,
    required this.userId,
    required this.version,
    required this.acceptedAt,
    this.ipAddress,
  });

  factory EulaAcceptance.fromJson(Map<String, dynamic> json, String id) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) {
        return DateTime.parse(value);
      }
      return DateTime.now();
    }

    return EulaAcceptance(
      id: id,
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      version: json['version'] as String,
      acceptedAt: parseDate(json['accepted_at'] ?? json['acceptedAt']),
      ipAddress: json['ip_address'] as String? ?? json['ipAddress'] as String?,
    );
  }

  factory EulaAcceptance.fromApiJson(Map<String, dynamic> json) {
    return EulaAcceptance.fromJson(
      json,
      json['id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'version': version,
      'acceptedAt': Timestamp.fromDate(acceptedAt),
      if (ipAddress != null) 'ipAddress': ipAddress,
    };
  }
}
