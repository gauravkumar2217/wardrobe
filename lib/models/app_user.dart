/// Authenticated app user (Laravel API session).
class AppUser {
  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? phoneNumber;
  final String? username;

  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    this.phoneNumber,
    this.username,
  });

  /// Compatibility alias used across the app (formerly Firebase `uid`).
  String get uid => id;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String?,
      displayName: json['display_name'] as String? ?? json['displayName'] as String?,
      photoUrl: json['photo_url'] as String? ?? json['photoUrl'] as String?,
      phoneNumber: json['phone'] as String? ??
          json['phone_number'] as String? ??
          json['phoneNumber'] as String?,
      username: json['username'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (email != null) 'email': email,
        if (displayName != null) 'display_name': displayName,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (phoneNumber != null) 'phone': phoneNumber,
        if (username != null) 'username': username,
      };
}
