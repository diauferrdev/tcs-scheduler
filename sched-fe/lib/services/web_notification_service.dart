import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'navigation_service.dart';
import 'web_notification_interop.dart' if (dart.library.io) 'web_notification_interop_stub.dart';
import 'web_html_stub.dart' if (dart.library.html) 'dart:html' as html;

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
      return;
    }

    if (!kIsWeb) {
      return;
    }


    try {
      // Inject helper scripts for push notifications
      injectBase64Helper();
      injectPushManagerHelper();

      // Check if Service Worker is supported
      if (!isServiceWorkerSupported()) {
        return;
      }

      // Wait for Service Worker to be ready
      await _waitForServiceWorker();

      // Request notification permission
      final permission = await _requestPermission();
      if (permission != 'granted') {
        return;
      }

      // Subscribe to push notifications
      await _subscribeToPush();

      // Setup Service Worker message listener for notification clicks
      _setupServiceWorkerListener();

      _initialized = true;
    } catch (e) {
    }
  }

  /// Setup listener for Service Worker navigation messages
  void _setupServiceWorkerListener() {
    if (!kIsWeb) {
      return;
    }

    try {

      // Setup JS listener using interop
      setupServiceWorkerMessageListener((url, bookingId, screen) {
        // This will be called from JS
      });

      // Listen for custom event from JavaScript
      html.window.addEventListener('flutter_navigate', (event) {
        final customEvent = event as html.CustomEvent;
        final detail = customEvent.detail as Map<String, dynamic>?;

        if (detail != null) {
          final url = detail['url'] as String?;
          final bookingId = detail['bookingId'] as String?;
          final screen = detail['screen'] as String?;


          // Navigate using NavigationService
          final navigationService = NavigationService();

          if (screen == 'approvals' && bookingId != null && bookingId.isNotEmpty) {
            navigationService.navigateToApprovalsWithBooking(bookingId);
          } else if (screen == 'my_bookings') {
            if (bookingId != null && bookingId.isNotEmpty) {
              navigationService.navigateToBookingDetails(bookingId);
            } else {
              navigationService.navigateToMyBookings();
            }
          } else if (bookingId != null && bookingId.isNotEmpty) {
            navigationService.navigateToBookingDetails(bookingId);
          } else if (url != null && url.isNotEmpty && url != '/') {
            navigationService.navigateTo(url);
          }
        }
      });

    } catch (e) {
    }
  }

  /// Wait for Service Worker to be ready
  Future<void> _waitForServiceWorker() async {

    // Add delay to ensure SW is registered from index.html
    await Future.delayed(const Duration(seconds: 2));

  }

  /// Request notification permission from user
  Future<String> _requestPermission() async {

    try {
      // Check current permission first
      final currentPermission = getNotificationPermission();
      if (currentPermission == 'granted') {
        return 'granted';
      }

      // Request permission
      final permission = await requestWebNotificationPermission();
      return permission;
    } catch (e) {
      return 'denied';
    }
  }

  /// Subscribe to push notifications
  Future<void> _subscribeToPush() async {

    try {
      // Get VAPID public key from backend
      final vapidKey = await _getVapidPublicKey();
      if (vapidKey == null) {
        return;
      }


      // Subscribe to push notifications with VAPID key
      final subscriptionJson = await subscribeToPushNotifications(vapidKey);
      if (subscriptionJson == null) {
        return;
      }


      // Send subscription to backend
      await _sendSubscriptionToBackend(subscriptionJson);

    } catch (e) {
    }
  }

  /// Get VAPID public key from backend
  Future<String?> _getVapidPublicKey() async {
    try {
      final response = await _apiService.get('/api/push/vapid-public-key');
      return response['publicKey'] as String?;
    } catch (e) {
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
    } catch (e) {
    }
  }

  /// Show a local notification (when app is open)
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (!kIsWeb) return;


    try {
      // Always try to show notification, even if not fully initialized
      // This ensures notifications work even if push subscription failed
      showBrowserNotification(title, body);
    } catch (e, stack) {
    }
  }

  /// Check if notifications are supported and permitted
  bool get isSupported => kIsWeb && _initialized;

  /// Get current subscription
  String? get subscription => _subscription;
}
