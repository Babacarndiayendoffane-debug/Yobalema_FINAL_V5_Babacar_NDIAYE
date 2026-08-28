enum UserRole { passenger, driver }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
  });

  final String id;
  final String name;
  final String phone;
  final UserRole role;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString().toUpperCase() == 'DRIVER'
          ? UserRole.driver
          : UserRole.passenger,
    );
  }
}
