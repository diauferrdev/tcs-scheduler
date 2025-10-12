import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../services/unified_notification_service.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final UnifiedNotificationService _notificationService = UnifiedNotificationService();
  int _unreadCount = 0;
  StreamSubscription? _badgeSubscription;

  @override
  void initState() {
    super.initState();

    // Get current count
    _unreadCount = _notificationService.unreadCount;

    // Listen to badge updates
    _badgeSubscription = _notificationService.badgeStream.listen((count) {
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    });

    debugPrint('[NotificationBell] Initialized with count: $_unreadCount');
  }

  @override
  void dispose() {
    _badgeSubscription?.cancel();
    super.dispose();
  }

  void _navigateToNotifications() {
    context.go('/notifications');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        IconButton(
          onPressed: _navigateToNotifications,
          icon: Icon(
            Icons.notifications_outlined,
            color: isDark ? Colors.white : Colors.black,
          ),
          tooltip: 'Notifications',
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
