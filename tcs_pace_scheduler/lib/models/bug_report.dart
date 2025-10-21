enum Platform {
  WINDOWS,
  LINUX,
  MACOS,
  ANDROID,
  IOS,
  WEB,
}

enum BugStatus {
  OPEN,
  IN_PROGRESS,
  RESOLVED,
  CLOSED,
}

class BugAttachment {
  final String id;
  final String fileUrl;
  final String fileName;
  final int fileSize;
  final String fileType;
  final DateTime createdAt;

  BugAttachment({
    required this.id,
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.createdAt,
  });

  factory BugAttachment.fromJson(Map<String, dynamic> json) {
    return BugAttachment(
      id: json['id'],
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      fileSize: json['fileSize'],
      fileType: json['fileType'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileType': fileType,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class BugLike {
  final String id;
  final String userId;
  final String userName;
  final DateTime createdAt;

  BugLike({
    required this.id,
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  factory BugLike.fromJson(Map<String, dynamic> json) {
    return BugLike(
      id: json['id'],
      userId: json['user']['id'],
      userName: json['user']['name'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class BugReporter {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;

  BugReporter({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
  });

  factory BugReporter.fromJson(Map<String, dynamic> json) {
    return BugReporter(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      avatarUrl: json['avatarUrl'],
    );
  }
}

class BugReport {
  final String id;
  final String title;
  final String description;
  final Platform platform;
  final Map<String, dynamic>? deviceInfo;
  final BugStatus status;
  final List<BugAttachment> attachments;
  final List<BugLike> likes;
  final int likeCount;
  final BugReporter reportedBy;
  final BugReporter? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  BugReport({
    required this.id,
    required this.title,
    required this.description,
    required this.platform,
    this.deviceInfo,
    required this.status,
    required this.attachments,
    required this.likes,
    required this.likeCount,
    required this.reportedBy,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BugReport.fromJson(Map<String, dynamic> json) {
    return BugReport(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      platform: Platform.values.firstWhere(
        (p) => p.name == json['platform'],
        orElse: () => Platform.WEB,
      ),
      deviceInfo: json['deviceInfo'] as Map<String, dynamic>?,
      status: BugStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => BugStatus.OPEN,
      ),
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((a) => BugAttachment.fromJson(a))
              .toList() ??
          [],
      likes: (json['likes'] as List<dynamic>?)
              ?.map((l) => BugLike.fromJson(l))
              .toList() ??
          [],
      likeCount: json['likeCount'] ?? 0,
      reportedBy: BugReporter.fromJson(json['reportedBy']),
      resolvedBy: json['resolvedBy'] != null
          ? BugReporter.fromJson(json['resolvedBy'])
          : null,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'])
          : null,
      resolutionNotes: json['resolutionNotes'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'platform': platform.name,
      'deviceInfo': deviceInfo,
      'status': status.name,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'likeCount': likeCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get platformDisplay {
    switch (platform) {
      case Platform.WINDOWS:
        return 'Windows';
      case Platform.LINUX:
        return 'Linux';
      case Platform.MACOS:
        return 'macOS';
      case Platform.ANDROID:
        return 'Android';
      case Platform.IOS:
        return 'iOS';
      case Platform.WEB:
        return 'Web';
    }
  }

  String get statusDisplay {
    switch (status) {
      case BugStatus.OPEN:
        return 'Open';
      case BugStatus.IN_PROGRESS:
        return 'In Progress';
      case BugStatus.RESOLVED:
        return 'Resolved';
      case BugStatus.CLOSED:
        return 'Closed';
    }
  }
}
