class Invitation {
  final String id;
  final String token;
  final String? email;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final bool isActive;
  final String createdById;
  final DateTime createdAt;
  final InvitationCreator? createdBy;

  Invitation({
    required this.id,
    required this.token,
    this.email,
    required this.expiresAt,
    this.usedAt,
    required this.isActive,
    required this.createdById,
    required this.createdAt,
    this.createdBy,
  });

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      id: json['id'] as String,
      token: json['token'] as String,
      email: json['email'] as String?,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      usedAt: json['usedAt'] != null ? DateTime.parse(json['usedAt'] as String) : null,
      isActive: json['isActive'] as bool,
      createdById: json['createdById'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdBy: json['createdBy'] != null
          ? InvitationCreator.fromJson(json['createdBy'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isUsed => usedAt != null;

  String get status {
    if (isUsed) return 'Used';
    if (isExpired) return 'Expired';
    if (isActive) return 'Active';
    return 'Inactive';
  }
}

class InvitationCreator {
  final String id;
  final String name;
  final String email;

  InvitationCreator({
    required this.id,
    required this.name,
    required this.email,
  });

  factory InvitationCreator.fromJson(Map<String, dynamic> json) {
    return InvitationCreator(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }
}
