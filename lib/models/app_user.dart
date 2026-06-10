/// Authenticated app user (Laravel API session).
class AppUser {
  final String id;
  final String? email;
  final String? displayName;
  final String? firstName;
  final String? lastName;
  final String? photoUrl;
  final String? phoneNumber;
  final String? username;
  final String? provider;

  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.firstName,
    this.lastName,
    this.photoUrl,
    this.phoneNumber,
    this.username,
    this.provider,
  });

  /// Compatibility alias used across the app (formerly Firebase `uid`).
  String get uid => id;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String?,
      displayName: json['display_name'] as String? ?? json['displayName'] as String?,
      firstName: json['first_name'] as String? ?? json['firstName'] as String?,
      lastName: json['last_name'] as String? ?? json['lastName'] as String?,
      photoUrl: json['photo_url'] as String? ?? json['photoUrl'] as String?,
      phoneNumber: json['phone'] as String? ??
          json['phone_number'] as String? ??
          json['phoneNumber'] as String?,
      username: json['username'] as String?,
      provider: json['provider'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (email != null) 'email': email,
        if (displayName != null) 'display_name': displayName,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (phoneNumber != null) 'phone': phoneNumber,
        if (username != null) 'username': username,
        if (provider != null) 'provider': provider,
      };
}
