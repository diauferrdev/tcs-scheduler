import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'realtime_service.dart';
import 'local_notification_service.dart';
import 'desktop_notification_service.dart';
import 'web_notification_service.dart';
import 'api_service.dart';
import 'fcm_service.dart';

// Re-export for background handler in main.dart
export 'local_notification_service.dart' show NotificationResponse;

/// Unified Notification Service
/// Manages real-time notifications and calendar updates across all platforms via Native WebSocket
class UnifiedNotificationService {
  static final UnifiedNotificationService _instance = UnifiedNotificationService._internal();
  factory UnifiedNotificationService() => _instance;
  UnifiedNotificationService._internal();

  final RealtimeService _realtimeService = RealtimeService();
  final LocalNotificationService _localNotificationService = LocalNotificationService();
  final DesktopNotificationService _desktopNotificationService = DesktopNotificationService();
  final WebNotificationService _webNotificationService = WebNotificationService();
  final ApiService _apiService = ApiService();

  // FCMService - Only for platforms that support Firebase
  // Windows and Linux use local_notifier instead
  FCMService? _fcmService;

  /// Check if Firebase is supported on current platform
  /// Firebase is supported on: Android, iOS, web, macOS
  /// NOT supported on: Windows, Linux
  bool get _isFirebaseSupported {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  // Stream controller for badge updates
  final StreamController<int> _badgeController = StreamController<int>.broadcast();
  Stream<int> get badgeStream => _badgeController.stream;

  // Stream controller for new notifications
  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  // Stream controllers for real-time calendar updates
  final StreamController<Map<String, dynamic>> _bookingCreatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get bookingCreatedStream => _bookingCreatedController.stream;

  final StreamController<Map<String, dynamic>> _bookingUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get bookingUpdatedStream => _bookingUpdatedController.stream;

  final StreamController<String> _bookingDeletedController =
      StreamController<String>.broadcast();
  Stream<String> get bookingDeletedStream => _bookingDeletedController.stream;

  final StreamController<Map<String, dynamic>> _bookingApprovedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get bookingApprovedStream => _bookingApprovedController.stream;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  bool _initialized = false;

  /// Initialize the notification system
  /// Does NOT request permissions - call requestPermissionsAfterLogin() after user logs in
  ///
  /// [onBackgroundNotificationResponse] - Optional background handler for mobile notifications
  /// This handler runs in a separate isolate when notifications arrive with app closed (Android/iOS/macOS)
  Future<void> initialize({
    void Function(NotificationResponse)? onBackgroundNotificationResponse,
  }) async {
    if (_initialized) return;

    try {
      // Initialize notifications based on platform
      if (kIsWeb) {
        // Web: Initialize Web Notification API (permissions requested after login)
      } else if (Platform.isWindows || Platform.isLinux) {
        // Desktop (Windows/Linux): Use local_notifier
        await _desktopNotificationService.initialize();
      } else {
        // Mobile/macOS: Use flutter_local_notifications with background handler
        await _localNotificationService.initialize(
          onBackgroundNotificationResponse: onBackgroundNotificationResponse,
        );
      }

      // Setup Native WebSocket RealtimeService listeners
      _setupRealtimeListeners();

      _initialized = true;
    } catch (e) {
      debugPrint('[Notification] ❌ Init error: $e');
    }
  }

  /// Request notification permissions after user logs in
  /// Call this method ONLY after successful authentication
  /// Returns true if permissions were granted, false otherwise
  Future<bool> requestPermissionsAfterLogin() async {
    try {
      bool permissionGranted = false;

      // CRITICAL: Connect WebSocket FIRST (non-blocking)
      _realtimeService.connect();

      if (kIsWeb) {
        // Web: Initialize Web Notification API in background
        _webNotificationService.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {},
        );
        permissionGranted = true;
      } else if (Platform.isWindows || Platform.isLinux) {
        // Desktop: No permissions needed
        permissionGranted = true;
      } else {
        // Mobile/macOS: Request permissions
        permissionGranted = await _localNotificationService.requestPermissions();
      }

      // Initialize FCM for push notifications (app closed/minimized)
      if (_isFirebaseSupported) {
        _fcmService = FCMService();
        _fcmService!.initialize();
      }

      // Load initial unread count (non-blocking)
      refreshUnreadCount();

      return permissionGranted;
    } catch (e) {
      debugPrint('[Notification] ❌ Permission error: $e');
      return false;
    }
  }

  /// Setup Native WebSocket RealtimeService event listeners
  void _setupRealtimeListeners() {
    // === NOTIFICATION LISTENERS ===
    _realtimeService.onNewNotification = (notification) {
      _handleIncomingNotification(notification);
    };

    _realtimeService.onUnreadCountUpdated = (count) {
      _unreadCount = count;
      if (!_badgeController.isClosed) {
        _badgeController.add(_unreadCount);
      }
    };

    _realtimeService.onNotificationSync = (syncData) {
      final unreadCount = syncData['unreadCount'] as int?;
      if (unreadCount != null) {
        _unreadCount = unreadCount;
        if (!_badgeController.isClosed) {
          _badgeController.add(_unreadCount);
        }
      }
    };

    _realtimeService.onUnreadNotifications = (notifications) {
      // Could show each one or just update badge
    };

    _realtimeService.onNotificationConnected = () {
      refreshUnreadCount();
    };

    _realtimeService.onNotificationDisconnected = () {
      // Auto-reconnects via RealtimeService
    };

    // === CALENDAR/BOOKING LISTENERS ===
    _realtimeService.onBookingCreated = (booking) {
      if (!_bookingCreatedController.isClosed) {
        _bookingCreatedController.add(booking);
      }
    };

    _realtimeService.onBookingUpdated = (booking) {
      if (!_bookingUpdatedController.isClosed) {
        _bookingUpdatedController.add(booking);
      }
    };

    _realtimeService.onBookingDeleted = (bookingId) {
      if (!_bookingDeletedController.isClosed) {
        _bookingDeletedController.add(bookingId);
      }
    };

    _realtimeService.onBookingApproved = (booking) {
      if (!_bookingApprovedController.isClosed) {
        _bookingApprovedController.add(booking);
      }
    };

    _realtimeService.onCalendarSync = (syncData) {
      // Could trigger full calendar refresh
    };

    _realtimeService.onCalendarConnected = () {};
    _realtimeService.onCalendarDisconnected = () {};
  }

  /// Handle incoming notification from WebSocket
  void _handleIncomingNotification(Map<String, dynamic> data) {
    debugPrint('[UnifiedNotification] WebSocket notification received');

    // Broadcast to listeners (only if not closed)
    if (!_notificationController.isClosed) {
      _notificationController.add(data);
    }

    // DUAL NOTIFICATION SYSTEM:
    // - FCM: Handles notifications when app is CLOSED/BACKGROUND (Android, iOS, Web)
    // - Local Notifications: Handles notifications when app is OPEN/FOREGROUND (all platforms)
    // Messages are now synchronized in backend, so both show identical content
    debugPrint('[UnifiedNotification] 🔔 App is OPEN - showing local notification (FCM handles when app is closed)');
    _showNativeNotification(data);

    // Increment badge count (only if not closed)
    _unreadCount++;
    if (!_badgeController.isClosed) {
      _badgeController.add(_unreadCount);
    }
  }

  /// Show native notification based on platform
  Future<void> _showNativeNotification(Map<String, dynamic> data) async {
    try {
      debugPrint('[UnifiedNotification] 🔔 _showNativeNotification() called');
      debugPrint('[UnifiedNotification] Data: $data');

      final title = data['title'] as String? ?? 'New Notification';
      final message = data['message'] as String? ?? '';
      final type = data['type'] as String?;
      final metadata = data['metadata'] as Map<String, dynamic>?;
      final bookingId = data['bookingId'] as String?;

      debugPrint('[UnifiedNotification] Title: $title, Type: $type, Platform: ${kIsWeb ? 'web' : Platform.operatingSystem}');

      if (kIsWeb) {
        // Web: Show browser notification when app is OPEN
        // User wants to see notifications even when page is open
        debugPrint('[UnifiedNotification] Web: Showing browser notification');
        await _webNotificationService.showNotification(
          title: title,
          body: message,
          data: {
            'type': type,
            'bookingId': bookingId,
            ...?metadata,
          },
        );
        return;
      }

      // Check if Windows/Linux desktop
      if (Platform.isWindows || Platform.isLinux) {
        // Desktop: Use local_notifier (simpler notifications)
        debugPrint('[UnifiedNotification] Showing desktop notification');
        await _showDesktopNotification(title, message, metadata);
        return;
      }

      // Mobile/macOS: Use flutter_local_notifications
      // IMPORTANT: Use generic notification to match FCM exactly
      // No emojis, no title modifications - use exact backend title and message
      debugPrint('[UnifiedNotification] Showing mobile/macOS notification (generic - matching FCM)');
      await _localNotificationService.showGenericNotification(
        title: title,
        message: message,
        bookingId: bookingId,
        metadata: {
          'type': type,
          ...?metadata,
        },
      );

      debugPrint('[UnifiedNotification] ✅ Native notification processing complete');
    } catch (e, stackTrace) {
      debugPrint('[UnifiedNotification] ❌ Error showing native notification: $e');
      debugPrint('[UnifiedNotification] Stack trace: $stackTrace');
    }
  }

  /// Show desktop notification (Windows/Linux)
  Future<void> _showDesktopNotification(
    String title,
    String message,
    Map<String, dynamic>? metadata,
  ) async {
    try {
      String body = message;

      // Add metadata to body if available
      if (metadata != null) {
        final companyName = metadata['companyName'] as String?;
        final date = metadata['date'] as String?;
        final time = metadata['time'] as String?;

        if (companyName != null) {
          body = '$message\n\nCompany: $companyName';
        }
        if (date != null && time != null) {
          body += '\nDate: $date at $time';
        }
      }

      await _desktopNotificationService.showNotification(
        title: title,
        body: body,
      );

      debugPrint('[UnifiedNotification] Desktop notification shown: $title');
    } catch (e) {
      debugPrint('[UnifiedNotification] Error showing desktop notification: $e');
    }
  }

  /// Refresh unread count from API
  Future<void> refreshUnreadCount() async {
    try {
      debugPrint('[UnifiedNotification] Fetching unread count from API...');

      final response = await _apiService.getNotifications(
        isRead: false,
        limit: 1, // Just need the count
        offset: 0,
      );

      debugPrint('[UnifiedNotification] API Response: $response');

      final count = response['unreadCount'] as int? ?? response['total'] as int? ?? 0;

      debugPrint('[UnifiedNotification] Extracted count: $count, Current count: $_unreadCount');

      if (_unreadCount != count) {
        final oldCount = _unreadCount;
        _unreadCount = count;
        if (!_badgeController.isClosed) {
          _badgeController.add(_unreadCount);
        }
        debugPrint('[UnifiedNotification] ✅ Badge updated: $oldCount → $_unreadCount');
      } else {
        debugPrint('[UnifiedNotification] Count unchanged, no update needed');
      }
    } catch (e) {
      debugPrint('[UnifiedNotification] ❌ Error refreshing unread count: $e');
    }
  }

  /// Mark notification as read (via Native WebSocket)
  Future<void> markAsRead(String notificationId) async {
    debugPrint('[UnifiedNotification] markAsRead called for: $notificationId');
    debugPrint('[UnifiedNotification] Current unread count: $_unreadCount');

    try {
      // Update via API
      debugPrint('[UnifiedNotification] Calling API to mark as read...');
      await _apiService.markNotificationAsRead(notificationId);
      debugPrint('[UnifiedNotification] API call successful');

      // Decrement local count immediately for instant UI update
      if (_unreadCount > 0) {
        _unreadCount--;
        if (!_badgeController.isClosed) {
          _badgeController.add(_unreadCount);
        }
        debugPrint('[UnifiedNotification] ✅ Badge decremented: ${_unreadCount + 1} → $_unreadCount');
      }

      // Refresh from server to ensure accuracy (runs in background)
      refreshUnreadCount();

      debugPrint('[UnifiedNotification] Marked as read: $notificationId');
    } catch (e) {
      debugPrint('[UnifiedNotification] Error marking as read: $e');
      // Refresh count on error to restore correct value
      await refreshUnreadCount();
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      // Update via API
      await _apiService.markAllNotificationsAsRead();

      // Set local count to 0 immediately for instant UI update
      final oldCount = _unreadCount;
      _unreadCount = 0;
      if (!_badgeController.isClosed) {
        _badgeController.add(_unreadCount);
      }
      debugPrint('[UnifiedNotification] ✅ Badge cleared: $oldCount → 0');

      // Refresh from server to ensure accuracy (runs in background)
      refreshUnreadCount();

      debugPrint('[UnifiedNotification] Marked all as read');
    } catch (e) {
      debugPrint('[UnifiedNotification] Error marking all as read: $e');
      // Refresh count on error to restore correct value
      await refreshUnreadCount();
      rethrow;
    }
  }

  /// Disconnect on logout (but keep service initialized for next login)
  Future<void> disconnectWebSocket() async {
    debugPrint('[UnifiedNotification] Disconnecting on logout...');

    await _realtimeService.disconnect();

    // Dispose FCM (delete token) - only if initialized
    if (_fcmService != null) {
      try {
        await _fcmService!.dispose();
        debugPrint('[UnifiedNotification] ✅ FCM cleaned up');
      } catch (e) {
        debugPrint('[UnifiedNotification] Error cleaning up FCM: $e');
      }
    }

    // Clear badge count
    _unreadCount = 0;
    if (!_badgeController.isClosed) {
      _badgeController.add(_unreadCount);
    }

    debugPrint('[UnifiedNotification] Cleanup complete on logout');
  }

  /// Cleanup
  Future<void> dispose() async {
    debugPrint('[UnifiedNotification] Disposing...');

    await _badgeController.close();
    await _notificationController.close();
    await _bookingCreatedController.close();
    await _bookingUpdatedController.close();
    await _bookingDeletedController.close();
    await _bookingApprovedController.close();
    await _realtimeService.disconnect();

    _initialized = false;
  }
}
