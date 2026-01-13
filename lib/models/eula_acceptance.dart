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
    return EulaAcceptance(
      id: id,
      userId: json['userId'] as String,
      version: json['version'] as String,
      acceptedAt: (json['acceptedAt'] as Timestamp).toDate(),
      ipAddress: json['ipAddress'] as String?,
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
