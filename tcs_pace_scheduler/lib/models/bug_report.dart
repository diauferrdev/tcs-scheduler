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
      fileSize: json['fileSize'] ?? 0,
      fileType: json['fileType'] ?? 'application/octet-stream',
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

class BugComment {
  final String id;
  final String content;
  final BugReporter user;
  final DateTime createdAt;
  final DateTime updatedAt;

  BugComment({
    required this.id,
    required this.content,
    required this.user,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BugComment.fromJson(Map<String, dynamic> json) {
    return BugComment(
      id: json['id'],
      content: json['content'],
      user: BugReporter.fromJson(json['user']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'user': user,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
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
  final List<BugComment>? comments;
  final List<BugLike> likes;
  final int likeCount;
  final int? commentCount; // Add count from _count.comments
  final BugReporter reportedBy;
  final BugReporter? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionNotes;
  final BugReporter? closedBy;
  final DateTime? closedAt;
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
    this.comments,
    required this.likes,
    required this.likeCount,
    this.commentCount,
    required this.reportedBy,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNotes,
    this.closedBy,
    this.closedAt,
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
      comments: (json['comments'] as List<dynamic>?)
              ?.map((c) => BugComment.fromJson(c))
              .toList(),
      likes: (json['likes'] as List<dynamic>?)
              ?.map((l) => BugLike.fromJson(l))
              .toList() ??
          [],
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['_count']?['comments'],
      reportedBy: BugReporter.fromJson(json['reportedBy']),
      resolvedBy: json['resolvedBy'] != null
          ? BugReporter.fromJson(json['resolvedBy'])
          : null,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'])
          : null,
      resolutionNotes: json['resolutionNotes'],
      closedBy: json['closedBy'] != null
          ? BugReporter.fromJson(json['closedBy'])
          : null,
      closedAt: json['closedAt'] != null
          ? DateTime.parse(json['closedAt'])
          : null,
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

  BugReport copyWith({
    String? id,
    String? title,
    String? description,
    Platform? platform,
    Map<String, dynamic>? deviceInfo,
    BugStatus? status,
    List<BugAttachment>? attachments,
    List<BugComment>? comments,
    List<BugLike>? likes,
    int? likeCount,
    int? commentCount,
    BugReporter? reportedBy,
    BugReporter? resolvedBy,
    DateTime? resolvedAt,
    String? resolutionNotes,
    BugReporter? closedBy,
    DateTime? closedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BugReport(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      platform: platform ?? this.platform,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      comments: comments ?? this.comments,
      likes: likes ?? this.likes,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      reportedBy: reportedBy ?? this.reportedBy,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      closedBy: closedBy ?? this.closedBy,
      closedAt: closedAt ?? this.closedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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
