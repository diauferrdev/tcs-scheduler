import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';

/// Desktop Notification Service (Windows/Linux)
/// Uses local_notifier for native desktop notifications
class DesktopNotificationService {
  static final DesktopNotificationService _instance = DesktopNotificationService._internal();
  factory DesktopNotificationService() => _instance;
  DesktopNotificationService._internal();

  bool _initialized = false;

  /// Initialize desktop notifications
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await localNotifier.setup(
        appName: 'TCS Pace Scheduler',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );

      _initialized = true;
      debugPrint('[DesktopNotification] Initialized successfully');
    } catch (e) {
      debugPrint('[DesktopNotification] Initialization error: $e');
    }
  }

  /// Show a simple notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? subtitle,
  }) async {
    if (!_initialized) {
      debugPrint('[DesktopNotification] Not initialized, skipping notification');
      return;
    }

    try {
      final notification = LocalNotification(
        title: title,
        body: body,
        subtitle: subtitle,
      );

      await notification.show();
      debugPrint('[DesktopNotification] Shown: $title');
    } catch (e) {
      debugPrint('[DesktopNotification] Error showing notification: $e');
    }
  }

  /// Show booking notification with details
  Future<void> showBookingNotification({
    required String title,
    required String companyName,
    required String date,
    required String time,
    String? additionalInfo,
  }) async {
    final body = '$companyName\n$date at $time${additionalInfo != null ? '\n$additionalInfo' : ''}';

    await showNotification(
      title: title,
      body: body,
    );
  }

  /// Check if running on supported desktop platform
  static bool isDesktopPlatform() {
    return !kIsWeb && (Platform.isWindows || Platform.isLinux);
  }
}
