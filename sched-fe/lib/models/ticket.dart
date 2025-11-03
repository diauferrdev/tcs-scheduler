// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart' show debugPrint;
import 'user.dart';

enum TicketStatus {
  OPEN,
  IN_PROGRESS,
  WAITING_USER,
  WAITING_ADMIN,
  RESOLVED,
  CLOSED,
}

enum TicketPriority {
  LOW,
  MEDIUM,
  HIGH,
  URGENT,
}

enum TicketCategory {
  BUG,
  FEATURE_REQUEST,
  QUESTION,
  IMPROVEMENT,
  OTHER,
}

enum Platform {
  WINDOWS,
  LINUX,
  MACOS,
  ANDROID,
  IOS,
  WEB,
}

enum MessageDeliveryStatus {
  SENDING,  // 1 check - enviando
  SENT,     // 2 checks - enviado
  READ,     // 2 checks azuis - lido
}

class TicketAttachment {
  final String id;
  final String fileName;
  final String fileUrl;
  final int fileSize;
  final String mimeType;
  final int? duration; // Audio duration in milliseconds (null for non-audio)
  final String uploadedById;
  final DateTime createdAt;

  TicketAttachment({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.mimeType,
    this.duration,
    required this.uploadedById,
    required this.createdAt,
  });

  factory TicketAttachment.fromJson(Map<String, dynamic> json) {
    return TicketAttachment(
      id: json['id'],
      fileName: json['fileName'],
      fileUrl: json['fileUrl'],
      fileSize: json['fileSize'],
      mimeType: json['mimeType'],
      duration: json['duration'],
      uploadedById: json['uploadedById'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'duration': duration,
      'uploadedById': uploadedById,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class TicketMessage {
  final String id;
  final String content;
  final bool isInternal;
  final String ticketId;
  final User author;
  final List<TicketAttachment> attachments;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  TicketMessage({
    required this.id,
    required this.content,
    required this.isInternal,
    required this.ticketId,
    required this.author,
    required this.attachments,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    try {
      return TicketMessage(
        id: json['id'] as String,
        content: json['content'] as String,
        isInternal: json['isInternal'] as bool? ?? false,
        ticketId: json['ticketId'] as String,
        author: User.fromJson(json['author'] as Map<String, dynamic>),
        attachments: (json['attachments'] as List?)
                ?.map((a) => TicketAttachment.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
        readAt: json['readAt'] != null ? DateTime.parse(json['readAt'] as String) : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
    } catch (e, stackTrace) {
      debugPrint('[TicketMessage.fromJson] ❌ Error parsing message: $e');
      debugPrint('[TicketMessage.fromJson] JSON: $json');
      debugPrint('[TicketMessage.fromJson] Stack: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isInternal': isInternal,
      'ticketId': ticketId,
      'author': author.toJson(),
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class Ticket {
  final String id;
  final String title;
  final String description;
  final TicketStatus status;
  final TicketPriority priority;
  final TicketCategory category;
  final Platform? platform;
  final User createdBy;
  final User? assignedTo;
  final List<TicketAttachment> attachments;
  final List<TicketMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;
  final int? messageCount;
  final int? attachmentCount;

  Ticket({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.category,
    this.platform,
    required this.createdBy,
    this.assignedTo,
    required this.attachments,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
    this.messageCount,
    this.attachmentCount,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      status: TicketStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
      ),
      priority: TicketPriority.values.firstWhere(
        (e) => e.toString().split('.').last == json['priority'],
      ),
      category: TicketCategory.values.firstWhere(
        (e) => e.toString().split('.').last == json['category'],
      ),
      platform: json['platform'] != null
          ? Platform.values.firstWhere(
              (e) => e.toString().split('.').last == json['platform'],
            )
          : null,
      createdBy: User.fromJson(json['createdBy']),
      assignedTo:
          json['assignedTo'] != null ? User.fromJson(json['assignedTo']) : null,
      attachments: (json['attachments'] as List?)
              ?.map((a) => TicketAttachment.fromJson(a))
              .toList() ??
          [],
      messages: (json['messages'] as List?)
              ?.map((m) => TicketMessage.fromJson(m))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      closedAt: json['closedAt'] != null ? DateTime.parse(json['closedAt']) : null,
      messageCount: json['_count']?['messages'],
      attachmentCount: json['_count']?['attachments'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'category': category.toString().split('.').last,
      'platform': platform?.toString().split('.').last,
      'createdBy': createdBy.toJson(),
      'assignedTo': assignedTo?.toJson(),
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
    };
  }

  String getStatusLabel() {
    switch (status) {
      case TicketStatus.OPEN:
        return 'Open';
      case TicketStatus.IN_PROGRESS:
        return 'In Progress';
      case TicketStatus.WAITING_USER:
        return 'Waiting for You';
      case TicketStatus.WAITING_ADMIN:
        return 'Waiting for Support';
      case TicketStatus.RESOLVED:
        return 'Resolved';
      case TicketStatus.CLOSED:
        return 'Closed';
    }
  }

  String getPriorityLabel() {
    switch (priority) {
      case TicketPriority.LOW:
        return 'Low';
      case TicketPriority.MEDIUM:
        return 'Medium';
      case TicketPriority.HIGH:
        return 'High';
      case TicketPriority.URGENT:
        return 'Urgent';
    }
  }

  String getCategoryLabel() {
    switch (category) {
      case TicketCategory.BUG:
        return 'Bug';
      case TicketCategory.FEATURE_REQUEST:
        return 'Feature Request';
      case TicketCategory.QUESTION:
        return 'Question';
      case TicketCategory.IMPROVEMENT:
        return 'Improvement';
      case TicketCategory.OTHER:
        return 'Other';
    }
  }
}
