// ignore_for_file: constant_identifier_names

enum UserRole { ADMIN, MANAGER, USER }

class User {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final List<UserRole> roles;
  final DateTime createdAt;
  final String? avatarUrl;
  final bool mustChangePassword;
  final bool isActive;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.roles = const [],
    required this.createdAt,
    this.avatarUrl,
    this.mustChangePassword = false,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final activeRole = UserRole.values.firstWhere(
      (e) => e.name == json['role'],
      orElse: () => UserRole.USER,
    );

    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: activeRole,
      roles: (json['roles'] as List?)
              ?.map((r) => UserRole.values.firstWhere(
                    (e) => e.name == r,
                    orElse: () => UserRole.USER,
                  ))
              .toList() ??
          [activeRole],
      createdAt: DateTime.parse(json['createdAt'] as String),
      avatarUrl: json['avatarUrl'] as String?,
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.name,
      'roles': roles.map((r) => r.name).toList(),
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'mustChangePassword': mustChangePassword,
      'isActive': isActive,
    };
  }

  bool get isAdmin => role == UserRole.ADMIN;
  bool get isManager => role == UserRole.MANAGER;
  bool get isUser => role == UserRole.USER;
  bool get hasMultipleRoles => roles.length > 1;
}
