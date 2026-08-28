enum UserRole { passenger, driver }

class User {
  final String id;
  final String name;
  final String phone;
  final UserRole role;

  const User({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final role = json['role']?.toString().toUpperCase();
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: role == 'DRIVER' ? UserRole.driver : UserRole.passenger,
    );
  }
}
