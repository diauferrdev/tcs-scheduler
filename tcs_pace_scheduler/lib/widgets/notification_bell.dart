import 'package:flutter/material.dart';
import 'dart:async';
import '../services/unified_notification_service.dart';
import '../screens/notifications_screen.dart';

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
    // Open notifications drawer from the bottom
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : const Color(0xFFF9FAFB),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: NotificationsDrawer(scrollController: scrollController),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
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
            right: 4,
            top: 4,
            child: IgnorePointer(
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
          ),
      ],
    );
  }
}
