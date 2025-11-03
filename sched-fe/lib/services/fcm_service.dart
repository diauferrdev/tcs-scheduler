import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
import 'navigation_service.dart';

/// Firebase Cloud Messaging Service
/// Handles push notifications that work even with app closed/minimized (like WhatsApp)
///
/// Architecture:
/// - WebSocket (via UnifiedNotificationService): Real-time updates when app is OPEN
/// - FCM: Push notifications when app is CLOSED/MINIMIZED/TERMINATED
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize FCM after user login
  /// Call this ONLY after successful authentication
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[FCM] Already initialized');
      return;
    }

    // Skip FCM on desktop platforms only (Windows/Linux use local notifications)
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      debugPrint('[FCM] Skipping FCM initialization on desktop (Windows/Linux)');
      return;
    }

    try {
      debugPrint('[FCM] Initializing on ${kIsWeb ? "Web" : Platform.operatingSystem}...');

      // Request notification permissions
      // IMPORTANT: All platforms need explicit permission now
      // - Android 13+ (API 33+): Runtime permission required
      // - iOS/macOS: Always requires permission
      // - Web: Browser permission dialog
      debugPrint('[FCM] Requesting notification permissions...');
      final NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] ❌ Permission denied by user');
        debugPrint('[FCM] Please enable notifications in device settings');
        return;
      }

      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        debugPrint('[FCM] ⚠️ Permission not determined - user did not respond');
        return;
      }

      debugPrint('[FCM] ✅ Notification permission granted!');

      // Get FCM token
      await _refreshFCMToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed');
        _fcmToken = newToken;
        _sendTokenToBackend(newToken);
      });

      // Setup foreground message handler
      // This handles push notifications when app is OPEN (foreground)
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Setup notification tap handler (app in background/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification (terminated state)
      final RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM] App opened from notification (terminated): ${initialMessage.notification?.title}');
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
      debugPrint('[FCM] ✅ Initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('[FCM] ❌ Initialization error: $e');
      debugPrint('[FCM] Stack trace: $stackTrace');
    }
  }

  /// Get and send FCM token to backend
  Future<void> _refreshFCMToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        _fcmToken = token;
        debugPrint('[FCM] Token obtained: ${token.substring(0, 20)}...');
        await _sendTokenToBackend(token);
      } else {
        debugPrint('[FCM] ⚠️ Failed to get FCM token');
      }
    } catch (e) {
      debugPrint('[FCM] Error getting token: $e');
    }
  }

  /// Send FCM token to backend for targeted push
  Future<void> _sendTokenToBackend(String token) async {
    try {
      debugPrint('[FCM] Sending token to backend...');

      // Get device info for identification
      String deviceInfo;
      if (kIsWeb) {
        deviceInfo = 'Web Browser';
      } else if (Platform.isAndroid) {
        deviceInfo = 'Android Device';
      } else if (Platform.isIOS) {
        deviceInfo = 'iOS Device';
      } else if (Platform.isMacOS) {
        deviceInfo = 'macOS Device';
      } else {
        deviceInfo = 'Unknown Device';
      }

      await _apiService.registerFCMToken(token, deviceInfo: deviceInfo);

      debugPrint('[FCM] ✅ Token sent to backend ($deviceInfo)');
    } catch (e) {
      debugPrint('[FCM] Error sending token to backend: $e');
    }
  }

  /// Handle foreground push notification (app is OPEN)
  /// When app is OPEN: WebSocket handles notifications (no visual notification needed)
  /// FCM only shows notifications when app is CLOSED/BACKGROUND
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM Foreground] Message received: ${message.notification?.title}');
    debugPrint('[FCM Foreground] Data: ${message.data}');
    debugPrint('[FCM Foreground] ℹ️ App is OPEN - WebSocket will handle notification');
    debugPrint('[FCM Foreground] ℹ️ No visual notification shown (avoiding duplicates)');

    // When app is OPEN:
    // - WebSocket receives the same notification and shows it in real-time
    // - UnifiedNotificationService handles the visual notification
    // - FCM should NOT show a duplicate notification

    // DO NOT show notification here - WebSocket handles it
    // This prevents duplicate notifications when app is open
  }

  /// Handle notification tap (app in background/terminated)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM Tap] ========================================');
    debugPrint('[FCM Tap] Notification tapped: ${message.notification?.title}');
    debugPrint('[FCM Tap] Full message data: ${message.data}');

    final notificationId = message.data['notificationId'] as String?;
    final bookingId = message.data['bookingId'] as String?;
    final type = message.data['type'] as String?;
    final screen = message.data['screen'] as String?;

    debugPrint('[FCM Tap] Extracted values:');
    debugPrint('[FCM Tap]   - NotificationId: $notificationId');
    debugPrint('[FCM Tap]   - BookingId: $bookingId');
    debugPrint('[FCM Tap]   - Type: $type');
    debugPrint('[FCM Tap]   - Screen: $screen');

    // Use Future.delayed to ensure navigation happens after app is fully ready
    // Increased delay to 1 second for background/terminated state
    Future.delayed(const Duration(milliseconds: 1000), () {
      try {
        debugPrint('[FCM Tap] Delay complete, starting navigation...');
        final navigationService = NavigationService();

        // Navigate based on 'screen' field from backend
        if (screen == 'approvals' && bookingId != null && bookingId.isNotEmpty) {
          // New booking notifications for managers - go to approvals screen
          debugPrint('[FCM Tap] ➡️ Navigating to approvals with booking: $bookingId');
          navigationService.navigateToApprovalsWithBooking(bookingId);
        } else if (screen == 'my_bookings') {
          // Booking cancelled, reschedule needed, etc. - go to my bookings
          debugPrint('[FCM Tap] ➡️ Navigating to my bookings');
          if (bookingId != null && bookingId.isNotEmpty) {
            debugPrint('[FCM Tap] ➡️ With booking details: $bookingId');
            navigationService.navigateToBookingDetails(bookingId);
          } else {
            navigationService.navigateToMyBookings();
          }
        } else if (bookingId != null && bookingId.isNotEmpty) {
          // Default: booking_details or no screen specified - show booking details
          debugPrint('[FCM Tap] ➡️ Navigating to booking details (default): $bookingId');
          navigationService.navigateToBookingDetails(bookingId);
        } else {
          // No bookingId and no specific screen - just open app
          debugPrint('[FCM Tap] ℹ️ No bookingId or screen - opening app without navigation');
        }

        debugPrint('[FCM Tap] ✅ Navigation call completed');
        debugPrint('[FCM Tap] ========================================');
      } catch (e, stackTrace) {
        debugPrint('[FCM Tap] ❌ Navigation error: $e');
        debugPrint('[FCM Tap] ❌ Stack trace: $stackTrace');
        debugPrint('[FCM Tap] ========================================');
      }
    });
  }

  /// Delete FCM token on logout
  Future<void> deleteToken() async {
    try {
      debugPrint('[FCM] Deleting token on logout...');
      await _messaging.deleteToken();
      _fcmToken = null;
      debugPrint('[FCM] ✅ Token deleted');
    } catch (e) {
      debugPrint('[FCM] Error deleting token: $e');
    }
  }

  /// Cleanup on logout
  Future<void> dispose() async {
    debugPrint('[FCM] Disposing...');
    await deleteToken();
    _initialized = false;
  }
}
