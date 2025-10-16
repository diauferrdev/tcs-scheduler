import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'web_notification_interop.dart' if (dart.library.io) 'web_notification_interop_stub.dart';

/// Web Notification Service
/// Handles Web Push Notifications using Service Worker and Push API
class WebNotificationService {
  static final WebNotificationService _instance = WebNotificationService._internal();
  factory WebNotificationService() => _instance;
  WebNotificationService._internal();

  final ApiService _apiService = ApiService();

  bool _initialized = false;
  String? _subscription;

  /// Initialize web push notifications
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[WebNotification] Already initialized');
      return;
    }

    if (!kIsWeb) {
      debugPrint('[WebNotification] Not running on web, skipping initialization');
      return;
    }

    debugPrint('[WebNotification] Initializing...');

    try {
      // Inject helper scripts for push notifications
      injectBase64Helper();
      injectPushManagerHelper();

      // Check if Service Worker is supported
      if (!isServiceWorkerSupported()) {
        debugPrint('[WebNotification] Service Workers not supported');
        return;
      }

      // Wait for Service Worker to be ready
      await _waitForServiceWorker();

      // Request notification permission
      final permission = await _requestPermission();
      if (permission != 'granted') {
        debugPrint('[WebNotification] Notification permission denied: $permission');
        return;
      }

      // Subscribe to push notifications
      await _subscribeToPush();

      _initialized = true;
      debugPrint('[WebNotification] ✅ Initialized successfully');
    } catch (e) {
      debugPrint('[WebNotification] ❌ Initialization error: $e');
    }
  }

  /// Wait for Service Worker to be ready
  Future<void> _waitForServiceWorker() async {
    debugPrint('[WebNotification] Waiting for Service Worker...');

    // Add delay to ensure SW is registered from index.html
    await Future.delayed(const Duration(seconds: 2));

    debugPrint('[WebNotification] Service Worker should be ready');
  }

  /// Request notification permission from user
  Future<String> _requestPermission() async {
    debugPrint('[WebNotification] Requesting notification permission...');

    try {
      // Check current permission first
      final currentPermission = getNotificationPermission();
      if (currentPermission == 'granted') {
        debugPrint('[WebNotification] Permission already granted');
        return 'granted';
      }

      // Request permission
      final permission = await requestWebNotificationPermission();
      debugPrint('[WebNotification] Permission result: $permission');
      return permission;
    } catch (e) {
      debugPrint('[WebNotification] Error requesting permission: $e');
      return 'denied';
    }
  }

  /// Subscribe to push notifications
  Future<void> _subscribeToPush() async {
    debugPrint('[WebNotification] Subscribing to push notifications...');

    try {
      // Get VAPID public key from backend
      final vapidKey = await _getVapidPublicKey();
      if (vapidKey == null) {
        debugPrint('[WebNotification] Failed to get VAPID key');
        return;
      }

      debugPrint('[WebNotification] Got VAPID key');

      // Subscribe to push notifications with VAPID key
      final subscriptionJson = await subscribeToPushNotifications(vapidKey);
      if (subscriptionJson == null) {
        debugPrint('[WebNotification] Failed to create subscription');
        return;
      }

      debugPrint('[WebNotification] Subscription created');

      // Send subscription to backend
      await _sendSubscriptionToBackend(subscriptionJson);

      debugPrint('[WebNotification] ✅ Push subscription complete');
    } catch (e) {
      debugPrint('[WebNotification] Error subscribing to push: $e');
    }
  }

  /// Get VAPID public key from backend
  Future<String?> _getVapidPublicKey() async {
    try {
      final response = await _apiService.get('/api/push/vapid-public-key');
      return response['publicKey'] as String?;
    } catch (e) {
      debugPrint('[WebNotification] Error getting VAPID key: $e');
      return null;
    }
  }

  /// Send subscription to backend
  Future<void> _sendSubscriptionToBackend(String subscriptionJson) async {
    try {
      // Parse subscription JSON to send in correct format
      final subscriptionData = jsonDecode(subscriptionJson);

      await _apiService.post('/api/push/subscribe', subscriptionData);

      _subscription = subscriptionJson;
      debugPrint('[WebNotification] Subscription sent to backend');
    } catch (e) {
      debugPrint('[WebNotification] Error sending subscription: $e');
    }
  }

  /// Show a local notification (when app is open)
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (!kIsWeb) return;

    debugPrint('[WebNotification] 🔔 showNotification() called');
    debugPrint('[WebNotification] Title: $title');
    debugPrint('[WebNotification] Body: $body');
    debugPrint('[WebNotification] Initialized: $_initialized');
    debugPrint('[WebNotification] Permission: ${getNotificationPermission()}');

    try {
      // Always try to show notification, even if not fully initialized
      // This ensures notifications work even if push subscription failed
      showBrowserNotification(title, body);
      debugPrint('[WebNotification] ✅ Notification display attempted');
    } catch (e, stack) {
      debugPrint('[WebNotification] ❌ Error showing notification: $e');
      debugPrint('[WebNotification] Stack: $stack');
    }
  }

  /// Check if notifications are supported and permitted
  bool get isSupported => kIsWeb && _initialized;

  /// Get current subscription
  String? get subscription => _subscription;
}
