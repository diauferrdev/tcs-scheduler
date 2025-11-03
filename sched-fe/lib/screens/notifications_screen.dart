import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/unified_notification_service.dart';
import '../models/notification.dart';
import '../utils/toast_notification.dart';

class NotificationsScreen extends StatefulWidget {
  final bool skipLayout;

  const NotificationsScreen({super.key, this.skipLayout = false});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  final UnifiedNotificationService _notificationService = UnifiedNotificationService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;

  // Real-time notification stream subscription
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupRealtimeListener();
  }

  /// Setup real-time listener for new notifications
  void _setupRealtimeListener() {
    debugPrint('[NotificationsScreen] Setting up real-time listener...');

    _notificationSubscription = _notificationService.notificationStream.listen(
      (notificationData) {
        debugPrint('[NotificationsScreen] Received new notification via stream: ${notificationData['title']}');

        if (!mounted) return;

        try {
          // Convert Map to AppNotification
          final newNotification = AppNotification.fromJson(notificationData);

          setState(() {
            // Add to top of list (newest first)
            _notifications.insert(0, newNotification);
          });

          // Show toast feedback
          ToastNotification.show(
            context,
            message: 'New notification: ${newNotification.title}',
            type: ToastType.success,
            duration: const Duration(seconds: 2),
          );

          debugPrint('[NotificationsScreen] ✅ Added new notification to list');
        } catch (e) {
          debugPrint('[NotificationsScreen] Error processing notification: $e');
        }
      },
      onError: (error) {
        debugPrint('[NotificationsScreen] Error in notification stream: $error');
      },
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getNotifications(limit: 100, offset: 0);
      final notificationsList = response['notifications'] as List?;

      if (notificationsList == null) {
        throw Exception('No notifications data received');
      }

      final notifications = notificationsList
          .map((n) => AppNotification.fromJson(n))
          .toList();

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[NotificationsScreen] Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleNotificationTap(AppNotification notification) async {
    // Just mark as read - don't navigate
    if (!notification.isRead) {
      await _markAsRead(notification);
    }
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) {
      return;
    }

    debugPrint('[NotificationsScreen] Marking notification as read: ${notification.id}');

    // Optimistic update - update UI immediately
    if (mounted) {
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = AppNotification(
            id: notification.id,
            type: notification.type,
            title: notification.title,
            message: notification.message,
            userId: notification.userId,
            bookingId: notification.bookingId,
            isRead: true,
            readAt: DateTime.now(),
            actionUrl: notification.actionUrl,
            metadata: notification.metadata,
            createdAt: notification.createdAt,
          );
        }
      });
    }

    // Then update backend in background
    try {
      await _notificationService.markAsRead(notification.id);
    } catch (e) {
      debugPrint('[NotificationsScreen] Error marking notification as read: $e');
      // Rollback on error
      if (mounted) {
        setState(() {
          final index = _notifications.indexWhere((n) => n.id == notification.id);
          if (index != -1) {
            _notifications[index] = notification; // Restore original
          }
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    // Optimistic update - mark all as read immediately
    final originalNotifications = List<AppNotification>.from(_notifications);
    if (mounted) {
      setState(() {
        _notifications = _notifications.map((n) => AppNotification(
          id: n.id,
          type: n.type,
          title: n.title,
          message: n.message,
          userId: n.userId,
          bookingId: n.bookingId,
          isRead: true,
          readAt: DateTime.now(),
          actionUrl: n.actionUrl,
          metadata: n.metadata,
          createdAt: n.createdAt,
        )).toList();
      });
    }

    try {
      await _notificationService.markAllAsRead();
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _notifications = originalNotifications;
        });
        ToastNotification.show(
          context,
          message: 'Error: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await _apiService.deleteNotification(id);

      if (mounted) {
        setState(() {
          _notifications.removeWhere((n) => n.id == id);
        });
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Error: $e',
          type: ToastType.error,
        );
      }
    }
  }

  List<AppNotification> _sortNotifications() {
    // Sort: Unread first, then by date (newest first)
    final sorted = List<AppNotification>.from(_notifications);
    sorted.sort((a, b) {
      if (a.isRead != b.isRead) {
        return a.isRead ? 1 : -1; // Unread first
      }
      return b.createdAt.compareTo(a.createdAt); // Newest first
    });
    return sorted;
  }

  void _showNotificationMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF18181B)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  'Test Push Notifications',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Send real-time push notifications to all admin/manager devices',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),

              const Divider(),

              // Notification options (scrollable)
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildNotificationOption(
                      icon: Icons.add_circle,
                      color: Colors.green,
                      title: 'New Booking',
                      subtitle: 'Send to all admins/managers',
                      onTap: () => _sendPushNotification(
                        type: 'BOOKING_CONFIRMED',
                        title: 'New Booking Confirmed',
                        message: 'TCS Consulting scheduled a visit for Oct 15, 2025 at 14:00',
                        metadata: {
                          'companyName': 'TCS Consulting',
                          'date': '15/10/2025',
                          'time': '14:00',
                          'sector': 'Technology & Innovation',
                          'expectedAttendees': 15,
                          'eventType': 'Innovation Day',
                        },
                      ),
                    ),
                    _buildNotificationOption(
                      icon: Icons.update,
                      color: Colors.blue,
                      title: 'Booking Updated',
                      subtitle: 'Notify changes to all',
                      onTap: () => _sendPushNotification(
                        type: 'BOOKING_UPDATED',
                        title: 'Booking Updated',
                        message: 'Accenture booking updated: attendees increased',
                        metadata: {
                          'companyName': 'Accenture',
                          'previousDate': 'Oct 18, 2025',
                          'newDate': 'Oct 20, 2025',
                          'previousTime': '10:00 AM',
                          'newTime': '2:00 PM',
                        },
                      ),
                    ),
                    _buildNotificationOption(
                      icon: Icons.cancel,
                      color: Colors.red,
                      title: 'Booking Cancelled',
                      subtitle: 'Alert cancellation',
                      onTap: () => _sendPushNotification(
                        type: 'BOOKING_CANCELLED',
                        title: 'Booking Cancelled',
                        message: 'IBM Brasil cancelled their visit due to schedule conflict',
                        metadata: {
                          'companyName': 'IBM Brasil',
                          'date': 'Oct 18, 2025',
                          'time': '9:00 AM',
                          'reason': 'Client schedule conflict',
                        },
                      ),
                    ),
                    _buildNotificationOption(
                      icon: Icons.check_circle,
                      color: Colors.green,
                      title: 'Booking Approved',
                      subtitle: 'Confirm approval',
                      onTap: () => _sendPushNotification(
                        type: 'BOOKING_APPROVED',
                        title: 'Booking Approved',
                        message: 'Microsoft visit approved by John Silva',
                        metadata: {
                          'companyName': 'Microsoft',
                          'date': 'Oct 22, 2025',
                          'time': '10:30 AM',
                          'approvedBy': 'John Silva (Manager)',
                        },
                      ),
                    ),
                    _buildNotificationOption(
                      icon: Icons.event_repeat,
                      color: Colors.blue,
                      title: 'Booking Rescheduled',
                      subtitle: 'Notify time change',
                      onTap: () => _sendPushNotification(
                        type: 'BOOKING_RESCHEDULED',
                        title: 'Booking Rescheduled',
                        message: 'SAP visit moved to a new date',
                        metadata: {
                          'companyName': 'SAP',
                          'previousDate': 'Nov 1, 2025',
                          'newDate': 'Nov 5, 2025',
                        },
                      ),
                    ),
                    _buildNotificationOption(
                      icon: Icons.science,
                      color: Colors.deepPurple,
                      title: 'Generic Test',
                      subtitle: 'Simple test notification',
                      onTap: () => _sendPushNotification(
                        type: 'BOOKING_UPDATED',
                        title: 'Test Notification',
                        message: 'This is a test push notification from Flutter app',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendPushNotification({
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    Navigator.pop(context); // Close menu

    try {
      debugPrint('[NotificationsScreen] Sending push notification: $type');

      await _apiService.sendTestNotification(
        type: type,
        title: title,
        message: message,
        metadata: metadata,
      );

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Push notification sent to all devices!',
          type: ToastType.success,
          duration: const Duration(seconds: 2),
        );
      }

      // Refresh notifications list after a short delay
      await Future.delayed(const Duration(seconds: 2));
      await _loadNotifications();
    } catch (e) {
      debugPrint('[NotificationsScreen] Error sending push: $e');

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Error: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Widget _buildNotificationOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Notifications'),
        elevation: 0,
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        color: isDark ? Colors.white : Colors.black,
        child: _buildBody(isDark),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNotificationMenu,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.notifications_active),
        label: const Text('Test'),
        tooltip: 'Test local notifications',
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: isDark ? Colors.white : Colors.black,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final sortedNotifications = _sortNotifications();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedNotifications.length,
      itemBuilder: (context, index) {
        final notification = sortedNotifications[index];
        return _buildNotificationCard(notification, isDark);
      },
    );
  }

  Widget _buildNotificationCard(AppNotification notification, bool isDark) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteNotification(notification.id),
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: notification.isRead
                  ? (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB))
                  : (isDark ? Colors.white24 : Colors.black12),
              width: notification.isRead ? 1 : 2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNotificationIcon(notification.type, isDark),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTimestamp(notification.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey[500]
                            : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationType type, bool isDark) {
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.BOOKING_INVITATION:
        icon = Icons.mail_outline;
        color = Colors.blue;
        break;
      case NotificationType.BOOKING_CONFIRMED:
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case NotificationType.BOOKING_APPROVED:
        icon = Icons.verified;
        color = Colors.green;
        break;
      case NotificationType.BOOKING_UPDATED:
        icon = Icons.update;
        color = Colors.orange;
        break;
      case NotificationType.BOOKING_CANCELLED:
        icon = Icons.cancel_outlined;
        color = Colors.red;
        break;
      case NotificationType.BOOKING_IMPORTANT_CHANGE:
        icon = Icons.priority_high;
        color = Colors.deepOrange;
        break;
      case NotificationType.BOOKING_RESCHEDULED:
        icon = Icons.event_repeat;
        color = Colors.blue;
        break;
      case NotificationType.BOOKING_NEED_EDIT:
        icon = Icons.edit_outlined;
        color = Colors.orange;
        break;
      case NotificationType.BOOKING_NEED_RESCHEDULE:
        icon = Icons.calendar_month;
        color = Colors.amber;
        break;
      case NotificationType.BOOKING_NOT_APPROVED:
        icon = Icons.block;
        color = Colors.red;
        break;
      case NotificationType.BOOKING_UNDER_REVIEW:
        icon = Icons.rate_review;
        color = const Color(0xFFF05E1B);
        break;
      case NotificationType.PARTICIPANT_CONFIRMED:
        icon = Icons.person_add_outlined;
        color = Colors.green;
        break;
      case NotificationType.PARTICIPANT_REJECTED:
        icon = Icons.person_remove_outlined;
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(timestamp);
    }
  }
}

// Drawer version of notifications screen
class NotificationsDrawer extends StatefulWidget {
  final ScrollController? scrollController;

  const NotificationsDrawer({super.key, this.scrollController});

  @override
  State<NotificationsDrawer> createState() => _NotificationsDrawerState();
}

class _NotificationsDrawerState extends State<NotificationsDrawer> {
  final ApiService _apiService = ApiService();
  final UnifiedNotificationService _notificationService = UnifiedNotificationService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _limit = 20;
  String? _error;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    _notificationSubscription = _notificationService.notificationStream.listen(
      (notificationData) {
        if (!mounted) return;
        try {
          final newNotification = AppNotification.fromJson(notificationData);
          setState(() {
            _notifications.insert(0, newNotification);
          });
        } catch (e) {
          debugPrint('[NotificationsDrawer] Error processing notification: $e');
        }
      },
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentOffset = 0;
      _hasMore = true;
    });

    try {
      final response = await _apiService.getNotifications(limit: _limit, offset: 0);
      final notificationsList = response['notifications'] as List?;

      if (notificationsList == null) {
        throw Exception('No notifications data received');
      }

      final notifications = notificationsList
          .map((n) => AppNotification.fromJson(n))
          .toList();

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
          _currentOffset = _limit;
          _hasMore = notifications.length == _limit;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _apiService.getNotifications(
        limit: _limit,
        offset: _currentOffset,
      );
      final notificationsList = response['notifications'] as List?;

      if (notificationsList == null) {
        throw Exception('No notifications data received');
      }

      final notifications = notificationsList
          .map((n) => AppNotification.fromJson(n))
          .toList();

      if (mounted) {
        setState(() {
          _notifications.addAll(notifications);
          _isLoadingMore = false;
          _currentOffset += _limit;
          _hasMore = notifications.length == _limit;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _handleNotificationTap(AppNotification notification) async {
    // Just mark as read - don't navigate
    if (!notification.isRead) {
      await _markAsRead(notification);
    }
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;

    // Optimistic update - update UI immediately
    if (mounted) {
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = AppNotification(
            id: notification.id,
            type: notification.type,
            title: notification.title,
            message: notification.message,
            userId: notification.userId,
            bookingId: notification.bookingId,
            isRead: true,
            readAt: DateTime.now(),
            actionUrl: notification.actionUrl,
            metadata: notification.metadata,
            createdAt: notification.createdAt,
          );
        }
      });
    }

    // Then update backend in background
    try {
      await _notificationService.markAsRead(notification.id);
    } catch (e) {
      debugPrint('[NotificationsDrawer] Error marking as read: $e');
      // Rollback on error
      if (mounted) {
        setState(() {
          final index = _notifications.indexWhere((n) => n.id == notification.id);
          if (index != -1) {
            _notifications[index] = notification; // Restore original
          }
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    // Optimistic update - mark all as read immediately
    final originalNotifications = List<AppNotification>.from(_notifications);
    if (mounted) {
      setState(() {
        _notifications = _notifications.map((n) => AppNotification(
          id: n.id,
          type: n.type,
          title: n.title,
          message: n.message,
          userId: n.userId,
          bookingId: n.bookingId,
          isRead: true,
          readAt: DateTime.now(),
          actionUrl: n.actionUrl,
          metadata: n.metadata,
          createdAt: n.createdAt,
        )).toList();
      });
    }

    try {
      await _notificationService.markAllAsRead();
    } catch (e) {
      debugPrint('[NotificationsDrawer] Error marking all as read: $e');
      // Rollback on error
      if (mounted) {
        setState(() {
          _notifications = originalNotifications;
        });
      }
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await _apiService.deleteNotification(id);
      if (mounted) {
        setState(() {
          _notifications.removeWhere((n) => n.id == id);
        });
      }
    } catch (e) {
      debugPrint('[NotificationsDrawer] Error deleting: $e');
    }
  }

  List<AppNotification> _sortNotifications() {
    final sorted = List<AppNotification>.from(_notifications);
    sorted.sort((a, b) {
      if (a.isRead != b.isRead) {
        return a.isRead ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Header - following BookingDetails pattern
        _buildDrawerHeader(isDark),

        // Body
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadNotifications,
            color: isDark ? Colors.white : Colors.black,
            child: _buildBody(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          // Close button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
            tooltip: 'Close',
          ),
          const SizedBox(width: 8),

          // Title
          Expanded(
            child: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),

          // Mark all read button (if unread exist)
          if (_notifications.any((n) => !n.isRead))
            IconButton(
              onPressed: _markAllAsRead,
              icon: Icon(Icons.done_all, color: isDark ? Colors.white : Colors.black),
              tooltip: 'Mark all read',
            ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: isDark ? Colors.white : Colors.black,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final sortedNotifications = _sortNotifications();

    return SingleChildScrollView(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Notification cards
          ...sortedNotifications.map((notification) => _buildNotificationCard(notification, isDark)),

          // Load more section
          if (_isLoadingMore)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            )
          else if (!_hasMore)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No more notifications',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: _loadMoreNotifications,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Load more'),
                ),
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification, bool isDark) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteNotification(notification.id),
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: notification.isRead
                  ? (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB))
                  : (isDark ? Colors.white24 : Colors.black12),
              width: notification.isRead ? 1 : 2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNotificationIcon(notification.type, isDark),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTimestamp(notification.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey[500]
                            : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationType type, bool isDark) {
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.BOOKING_INVITATION:
        icon = Icons.mail_outline;
        color = Colors.blue;
        break;
      case NotificationType.BOOKING_CONFIRMED:
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case NotificationType.BOOKING_APPROVED:
        icon = Icons.verified;
        color = Colors.green;
        break;
      case NotificationType.BOOKING_UPDATED:
        icon = Icons.update;
        color = Colors.orange;
        break;
      case NotificationType.BOOKING_CANCELLED:
        icon = Icons.cancel_outlined;
        color = Colors.red;
        break;
      case NotificationType.BOOKING_IMPORTANT_CHANGE:
        icon = Icons.priority_high;
        color = Colors.deepOrange;
        break;
      case NotificationType.BOOKING_RESCHEDULED:
        icon = Icons.event_repeat;
        color = Colors.blue;
        break;
      case NotificationType.BOOKING_NEED_EDIT:
        icon = Icons.edit_outlined;
        color = Colors.orange;
        break;
      case NotificationType.BOOKING_NEED_RESCHEDULE:
        icon = Icons.calendar_month;
        color = Colors.amber;
        break;
      case NotificationType.BOOKING_NOT_APPROVED:
        icon = Icons.block;
        color = Colors.red;
        break;
      case NotificationType.BOOKING_UNDER_REVIEW:
        icon = Icons.rate_review;
        color = const Color(0xFFF05E1B);
        break;
      case NotificationType.PARTICIPANT_CONFIRMED:
        icon = Icons.person_add_outlined;
        color = Colors.green;
        break;
      case NotificationType.PARTICIPANT_REJECTED:
        icon = Icons.person_remove_outlined;
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(timestamp);
    }
  }
}
