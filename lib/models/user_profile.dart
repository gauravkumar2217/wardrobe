class UserProfile {
  final String? name;
  final String? gender; // 'Male', 'Female', 'Other', or null
  final DateTime? birthday;

  UserProfile({
    this.name,
    this.gender,
    this.birthday,
  });

  // Check if profile is complete
  bool get isComplete {
    return name != null && 
           name!.isNotEmpty && 
           gender != null && 
           gender!.isNotEmpty &&
           birthday != null;
  }

  // Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (gender != null) 'gender': gender,
      if (birthday != null) 'birthday': birthday!.toIso8601String(),
    };
  }

  // Create from Firestore document
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String?,
      gender: json['gender'] as String?,
      birthday: json['birthday'] != null 
          ? DateTime.parse(json['birthday'] as String)
          : null,
    );
  }

  // Create a copy with updated fields
  UserProfile copyWith({
    String? name,
    String? gender,
    DateTime? birthday,
  }) {
    return UserProfile(
      name: name ?? this.name,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
    );
  }
}

