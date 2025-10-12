enum NotificationType {
  BOOKING_INVITATION,
  BOOKING_CONFIRMED,
  BOOKING_APPROVED,
  BOOKING_UPDATED,
  BOOKING_CANCELLED,
  BOOKING_PENDING_APPROVAL,
  BOOKING_IMPORTANT_CHANGE,
  BOOKING_RESCHEDULED,
  PARTICIPANT_CONFIRMED,
  PARTICIPANT_REJECTED,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final String userId;
  final String? bookingId;
  final bool isRead;
  final DateTime? readAt;
  final String? actionUrl;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.userId,
    this.bookingId,
    required this.isRead,
    this.readAt,
    this.actionUrl,
    this.metadata,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    // Find matching type or default to BOOKING_UPDATED if not found
    NotificationType notifType;
    try {
      notifType = NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.BOOKING_UPDATED,
      );
    } catch (e) {
      notifType = NotificationType.BOOKING_UPDATED;
    }

    return AppNotification(
      id: json['id'] as String,
      type: notifType,
      title: json['title'] as String,
      message: json['message'] as String,
      userId: json['userId'] as String,
      bookingId: json['bookingId'] as String?,
      isRead: json['isRead'] as bool,
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
      actionUrl: json['actionUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
