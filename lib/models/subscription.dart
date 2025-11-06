import 'package:cloud_firestore/cloud_firestore.dart';

class Subscription {
  final String name; // 'free' or 'pro'
  final int maxWardrobes; // -1 for unlimited
  final DateTime? expiresAt;
  final DateTime? purchasedAt;

  Subscription({
    required this.name,
    required this.maxWardrobes,
    this.expiresAt,
    this.purchasedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'maxWardrobes': maxWardrobes,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'purchasedAt': purchasedAt != null ? Timestamp.fromDate(purchasedAt!) : null,
    };
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      name: json['name'] as String? ?? 'free',
      maxWardrobes: json['maxWardrobes'] as int? ?? 2,
      expiresAt: json['expiresAt'] != null
          ? (json['expiresAt'] as Timestamp).toDate()
          : null,
      purchasedAt: json['purchasedAt'] != null
          ? (json['purchasedAt'] as Timestamp).toDate()
          : null,
    );
  }

  bool get isPro => name == 'pro';
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  static Subscription free() {
    return Subscription(
      name: 'free',
      maxWardrobes: 2,
    );
  }

  static Subscription pro({DateTime? expiresAt, DateTime? purchasedAt}) {
    return Subscription(
      name: 'pro',
      maxWardrobes: -1, // Unlimited
      expiresAt: expiresAt,
      purchasedAt: purchasedAt,
    );
  }
}

