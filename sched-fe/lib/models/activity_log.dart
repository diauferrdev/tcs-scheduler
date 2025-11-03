// ignore_for_file: constant_identifier_names

enum ActivityAction {
  LOGIN,
  LOGOUT,
  CREATE,
  UPDATE,
  DELETE,
  VIEW,
}

enum ActivityResource {
  BOOKING,
  INVITATION,
  USER,
  SESSION,
}

class ActivityLog {
  final String id;
  final ActivityAction action;
  final ActivityResource resource;
  final String? resourceId;
  final String description;
  final Map<String, dynamic>? metadata;
  final String? userId;
  final ActivityLogUser? user;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;

  ActivityLog({
    required this.id,
    required this.action,
    required this.resource,
    this.resourceId,
    required this.description,
    this.metadata,
    this.userId,
    this.user,
    this.ipAddress,
    this.userAgent,
    required this.createdAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as String,
      action: ActivityAction.values.firstWhere(
        (e) => e.name == json['action'],
      ),
      resource: ActivityResource.values.firstWhere(
        (e) => e.name == json['resource'],
      ),
      resourceId: json['resourceId'] as String?,
      description: json['description'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      userId: json['userId'] as String?,
      user: json['user'] != null
          ? ActivityLogUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      ipAddress: json['ipAddress'] as String?,
      userAgent: json['userAgent'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class ActivityLogUser {
  final String id;
  final String name;
  final String email;

  ActivityLogUser({
    required this.id,
    required this.name,
    required this.email,
  });

  factory ActivityLogUser.fromJson(Map<String, dynamic> json) {
    return ActivityLogUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }
}
