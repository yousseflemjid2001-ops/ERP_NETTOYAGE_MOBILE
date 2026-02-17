class User {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String role;
  final String status;
  final String? phone;
  final String? profilePhotoUrl;
  final String? createdAt;
  final String? lastLoginAt;

  User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    required this.role,
    required this.status,
    this.phone,
    this.profilePhotoUrl,
    this.createdAt,
    this.lastLoginAt,
  });

  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return email;
  }

  String get initials {
    if (firstName != null && lastName != null) {
      return '${firstName![0]}${lastName![0]}'.toUpperCase();
    }
    return email[0].toUpperCase();
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'],
      lastName: json['lastName'],
      role: json['role'] ?? '',
      status: json['status'] ?? '',
      phone: json['phone'],
      profilePhotoUrl: json['profilePhotoUrl'],
      createdAt: json['createdAt'],
      lastLoginAt: json['lastLoginAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'status': status,
      'phone': phone,
      'profilePhotoUrl': profilePhotoUrl,
      'createdAt': createdAt,
      'lastLoginAt': lastLoginAt,
    };
  }
}
