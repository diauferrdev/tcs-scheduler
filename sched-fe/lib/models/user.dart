// ignore_for_file: constant_identifier_names

enum UserRole { ADMIN, MANAGER, USER }

class User {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final DateTime createdAt;
  final String? avatarUrl;
  final bool mustChangePassword;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    this.avatarUrl,
    this.mustChangePassword = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.USER,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      avatarUrl: json['avatarUrl'] as String?,
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.name,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'mustChangePassword': mustChangePassword,
    };
  }

  bool get isAdmin => role == UserRole.ADMIN;
  bool get isManager => role == UserRole.MANAGER;
  bool get isUser => role == UserRole.USER;
}
