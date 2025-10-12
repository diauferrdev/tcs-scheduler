/// Stub implementation for non-web platforms
/// This file is used when compiling for mobile/desktop to avoid compilation errors

import 'package:flutter/foundation.dart';

/// Request notification permission (stub)
Future<String> requestWebNotificationPermission() async {
  debugPrint('[WebInterop] Stub: Not on web platform');
  return 'denied';
}

/// Get current permission status (stub)
String getNotificationPermission() {
  return 'denied';
}

/// Check if Service Worker is supported (stub)
bool isServiceWorkerSupported() {
  return false;
}

/// Show notification using browser API (stub)
void showBrowserNotification(String title, String body, {String? icon}) {
  debugPrint('[WebInterop] Stub: Not on web platform');
}

/// Subscribe to push notifications (stub)
Future<String?> subscribeToPushNotifications(String vapidPublicKey) async {
  debugPrint('[WebInterop] Stub: Not on web platform');
  return null;
}

/// Inject helper scripts (stub)
void injectBase64Helper() {
  // No-op on non-web platforms
}

void injectPushManagerHelper() {
  // No-op on non-web platforms
}
