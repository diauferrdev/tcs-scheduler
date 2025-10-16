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
  final FCMService _fcmService = FCMService();

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
    if (_initialized) {
      debugPrint('[UnifiedNotification] Already initialized');
      return;
    }

    debugPrint('[UnifiedNotification] Initializing (WITHOUT requesting permissions)...');
    debugPrint('[UnifiedNotification] Platform check: kIsWeb=$kIsWeb, Platform=${!kIsWeb ? Platform.operatingSystem : "web"}');

    try {
      // Initialize notifications based on platform
      if (kIsWeb) {
        // Web: Initialize Web Notification API (permissions requested after login)
        debugPrint('[UnifiedNotification] Web: Initializing (permissions will be requested after login)');
      } else if (Platform.isWindows || Platform.isLinux) {
        // Desktop (Windows/Linux): Use local_notifier
        debugPrint('[UnifiedNotification] Desktop detected: Initializing local_notifier...');
        await _desktopNotificationService.initialize();
        debugPrint('[UnifiedNotification] Initialized desktop notifications');
      } else {
        // Mobile/macOS: Use flutter_local_notifications with background handler
        debugPrint('[UnifiedNotification] Mobile/macOS detected: Initializing LocalNotificationService...');
        await _localNotificationService.initialize(
          onBackgroundNotificationResponse: onBackgroundNotificationResponse,
        );
        debugPrint('[UnifiedNotification] Initialized mobile/macOS notifications (permissions will be requested after login)');
      }

      // Setup Native WebSocket RealtimeService listeners
      _setupRealtimeListeners();

      // IMPORTANT: Do NOT connect to WebSocket during initialization
      // WebSocket requires session cookie which only exists AFTER login
      // Will connect via requestPermissionsAfterLogin() method after user logs in

      // Load initial unread count
      await refreshUnreadCount();

      _initialized = true;
      debugPrint('[UnifiedNotification] Initialized successfully (WebSocket will connect after login)');
    } catch (e) {
      debugPrint('[UnifiedNotification] Initialization error: $e');
    }
  }

  /// Request notification permissions after user logs in
  /// Call this method ONLY after successful authentication
  /// Returns true if permissions were granted, false otherwise
  Future<bool> requestPermissionsAfterLogin() async {
    debugPrint('[UnifiedNotification] Requesting permissions after login...');

    try {
      bool permissionGranted = false;

      if (kIsWeb) {
        // Web: Initialize Web Notification API and request permissions
        debugPrint('[UnifiedNotification] Web: Requesting notification permissions');
        await _webNotificationService.initialize();
        debugPrint('[UnifiedNotification] Web: Permissions request complete');
        permissionGranted = true;
      } else if (Platform.isWindows || Platform.isLinux) {
        // Desktop: No permissions needed
        debugPrint('[UnifiedNotification] Desktop: No permissions needed');
        permissionGranted = true;
      } else {
        // Mobile/macOS: Request permissions
        debugPrint('[UnifiedNotification] Mobile/macOS: Requesting permissions');
        permissionGranted = await _localNotificationService.requestPermissions();
        debugPrint('[UnifiedNotification] Mobile/macOS: Permissions ${permissionGranted ? 'granted' : 'denied'}');
      }

      // Initialize Firebase Cloud Messaging for push notifications (app closed/minimized)
      // This works like WhatsApp - notifications arrive even when app is completely closed
      debugPrint('[UnifiedNotification] Initializing FCM for push notifications...');
      _fcmService.initialize().then((_) {
        if (_fcmService.isInitialized) {
          debugPrint('[UnifiedNotification] ✅ FCM initialized - push notifications enabled');
        }
      }).catchError((e) {
        debugPrint('[UnifiedNotification] ⚠️ FCM initialization failed: $e');
      });

      // CRITICAL: Connect to Native WebSocket for instant real-time updates
      // Run in background - don't block login with await
      debugPrint('[UnifiedNotification] 🚀 Connecting to Native WebSocket (background)...');
      _realtimeService.connect().then((_) {
        if (_realtimeService.isFullyConnected) {
          debugPrint('[UnifiedNotification] ✅ WebSocket connected - instant real-time updates enabled');
        } else if (_realtimeService.isNotificationConnected) {
          debugPrint('[UnifiedNotification] ✅ WebSocket connected - instant updates enabled');
        } else {
          debugPrint('[UnifiedNotification] ⚠️ WebSocket connection failed');
        }
      }).catchError((e) {
        debugPrint('[UnifiedNotification] Error connecting to WebSocket: $e');
      });

      return permissionGranted;
    } catch (e) {
      debugPrint('[UnifiedNotification] Error requesting permissions: $e');
      return false;
    }
  }

  /// Setup Native WebSocket RealtimeService event listeners
  void _setupRealtimeListeners() {
    // === NOTIFICATION LISTENERS ===

    // Listen for new notifications from WebSocket
    _realtimeService.onNewNotification = (notification) {
      debugPrint('[UnifiedNotification] New notification via WebSocket: $notification');
      _handleIncomingNotification(notification);
    };

    // Listen for unread count updates
    _realtimeService.onUnreadCountUpdated = (count) {
      debugPrint('[UnifiedNotification] Unread count updated: $count');
      _unreadCount = count;
      if (!_badgeController.isClosed) {
        _badgeController.add(_unreadCount);
      }
    };

    // Listen for notification sync on connect
    _realtimeService.onNotificationSync = (syncData) {
      debugPrint('[UnifiedNotification] Notification sync: $syncData');
      final unreadCount = syncData['unreadCount'] as int?;
      if (unreadCount != null) {
        _unreadCount = unreadCount;
        if (!_badgeController.isClosed) {
          _badgeController.add(_unreadCount);
        }
      }
    };

    // Listen for batch of unread notifications
    _realtimeService.onUnreadNotifications = (notifications) {
      debugPrint('[UnifiedNotification] Received ${notifications.length} unread notifications');
      // Could show each one or just update badge
    };

    // Listen for connection events
    _realtimeService.onNotificationConnected = () {
      debugPrint('[UnifiedNotification] WebSocket connected');
      // Refresh count on reconnect
      refreshUnreadCount();
    };

    _realtimeService.onNotificationDisconnected = () {
      debugPrint('[UnifiedNotification] WebSocket disconnected');
      // Auto-reconnects via RealtimeService
    };

    // === CALENDAR/BOOKING LISTENERS ===

    // Listen for new booking creation
    _realtimeService.onBookingCreated = (booking) {
      debugPrint('[UnifiedNotification] 📅 New booking created via WebSocket: ${booking['companyName']}');
      if (!_bookingCreatedController.isClosed) {
        _bookingCreatedController.add(booking);
      }
    };

    // Listen for booking updates
    _realtimeService.onBookingUpdated = (booking) {
      debugPrint('[UnifiedNotification] 📅 Booking updated via WebSocket: ${booking['companyName']}');
      if (!_bookingUpdatedController.isClosed) {
        _bookingUpdatedController.add(booking);
      }
    };

    // Listen for booking deletions
    _realtimeService.onBookingDeleted = (bookingId) {
      debugPrint('[UnifiedNotification] 📅 Booking deleted via WebSocket: $bookingId');
      if (!_bookingDeletedController.isClosed) {
        _bookingDeletedController.add(bookingId);
      }
    };

    // Listen for booking approvals
    _realtimeService.onBookingApproved = (booking) {
      debugPrint('[UnifiedNotification] 📅 Booking approved via WebSocket: ${booking['companyName']}');
      if (!_bookingApprovedController.isClosed) {
        _bookingApprovedController.add(booking);
      }
    };

    // Listen for calendar sync on connect
    _realtimeService.onCalendarSync = (syncData) {
      debugPrint('[UnifiedNotification] Calendar sync: $syncData');
      // Could trigger full calendar refresh
    };

    _realtimeService.onCalendarConnected = () {
      debugPrint('[UnifiedNotification] Calendar WebSocket connected');
    };

    _realtimeService.onCalendarDisconnected = () {
      debugPrint('[UnifiedNotification] Calendar WebSocket disconnected');
    };
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

    // Dispose FCM (delete token)
    try {
      await _fcmService.dispose();
      debugPrint('[UnifiedNotification] ✅ FCM cleaned up');
    } catch (e) {
      debugPrint('[UnifiedNotification] Error cleaning up FCM: $e');
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
