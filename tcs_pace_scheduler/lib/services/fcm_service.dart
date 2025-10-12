import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
import 'local_notification_service.dart';

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
  final LocalNotificationService _localNotificationService = LocalNotificationService();

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

    // Skip FCM on web (web uses its own push API)
    if (kIsWeb) {
      debugPrint('[FCM] Skipping FCM initialization on web');
      return;
    }

    // Skip FCM on desktop platforms (use local notifications only)
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      debugPrint('[FCM] Skipping FCM initialization on desktop');
      return;
    }

    try {
      debugPrint('[FCM] Initializing...');

      // Request notification permissions (iOS/macOS)
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
        return;
      }

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

      await _apiService.registerFCMToken(token);

      debugPrint('[FCM] ✅ Token sent to backend');
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
    debugPrint('[FCM Tap] Notification tapped: ${message.notification?.title}');
    debugPrint('[FCM Tap] Data: ${message.data}');

    // TODO: Navigate to specific screen based on notification data
    final notificationId = message.data['notificationId'] as String?;
    final bookingId = message.data['bookingId'] as String?;
    final type = message.data['type'] as String?;

    debugPrint('[FCM Tap] NotificationId: $notificationId, BookingId: $bookingId, Type: $type');

    // Navigation will be handled by the app when it comes to foreground
    // You can use a navigation service or global navigator key here
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
