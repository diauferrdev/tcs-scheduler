@JS()
library;

import 'dart:js_interop';
import 'package:flutter/foundation.dart';

/// JavaScript Interop for Web Notification API
/// Provides direct access to browser notification APIs

@JS('Notification.permission')
external String get notificationPermission;

@JS('Notification.requestPermission')
external JSPromise requestNotificationPermission();

/// Request notification permission
Future<String> requestWebNotificationPermission() async {
  if (!kIsWeb) return 'denied';

  try {
    final result = await requestNotificationPermission().toDart;
    return result.toString();
  } catch (e) {
    return 'denied';
  }
}

/// Get current permission status
String getNotificationPermission() {
  if (!kIsWeb) return 'denied';

  try {
    return notificationPermission;
  } catch (e) {
    return 'denied';
  }
}

/// Check if Service Worker is supported
@JS('navigator.serviceWorker')
external JSObject? get serviceWorkerContainer;

bool isServiceWorkerSupported() {
  if (!kIsWeb) return false;

  try {
    return serviceWorkerContainer != null;
  } catch (e) {
    return false;
  }
}

/// Show a browser notification
@JS()
@anonymous
extension type NotificationOptions._(JSObject _) implements JSObject {
  external factory NotificationOptions({
    String? body,
    String? icon,
    String? badge,
    JSAny? data,
  });
}

@JS('Notification')
extension type Notification._(JSObject _) implements JSObject {
  external factory Notification(String title, [NotificationOptions? options]);
}

/// Show notification using browser API
void showBrowserNotification(String title, String body, {String? icon}) {
  if (!kIsWeb) return;

  try {

    if (notificationPermission == 'granted') {
      final notification = Notification(
        title,
        NotificationOptions(
          body: body,
          icon: icon ?? '/icons/Icon-192.png',
        ),
      );
    } else {
    }
  } catch (e, stack) {
  }
}

/// Get Service Worker registration
@JS('navigator.serviceWorker.ready')
external JSPromise get serviceWorkerReady;

/// Subscribe to push notifications
Future<String?> subscribeToPushNotifications(String vapidPublicKey) async {
  if (!kIsWeb) return null;

  try {

    // Wait for service worker to be ready
    final registrationAny = await serviceWorkerReady.toDart;
    if (registrationAny == null) {
      return null;
    }

    final registration = registrationAny as JSObject;

    // Convert VAPID key from base64 to Uint8Array
    final applicationServerKey = urlBase64ToUint8Array(vapidPublicKey);

    // Subscribe to push manager
    final subscription = await _subscribeWithOptions(registration, applicationServerKey);

    // Convert subscription to JSON string
    final subscriptionJson = _subscriptionToJson(subscription);

    return subscriptionJson;
  } catch (e) {
    return null;
  }
}

/// Convert URL-safe Base64 to Uint8Array
@JS('urlBase64ToUint8Array')
external JSUint8Array urlBase64ToUint8Array(String base64String);

// Add helper script to window for base64 conversion
void injectBase64Helper() {
  if (!kIsWeb) return;

  try {
    // This will be injected once
    _injectBase64HelperScript();
  } catch (e) {
  }
}

@JS('eval')
external void _eval(String code);

void _injectBase64HelperScript() {
  const script = '''
    if (typeof window.urlBase64ToUint8Array === 'undefined') {
      window.urlBase64ToUint8Array = function(base64String) {
        const padding = '='.repeat((4 - base64String.length % 4) % 4);
        const base64 = (base64String + padding)
          .replace(/-/g, '+')
          .replace(/_/g, '/');

        const rawData = window.atob(base64);
        const outputArray = new Uint8Array(rawData.length);

        for (let i = 0; i < rawData.length; ++i) {
          outputArray[i] = rawData.charCodeAt(i);
        }
        return outputArray;
      };
    }
  ''';

  try {
    _eval(script);
  } catch (e) {
  }
}

/// Subscribe with push manager options
Future<JSObject> _subscribeWithOptions(JSObject registration, JSUint8Array applicationServerKey) async {
  // Using dynamic JS interop for complex objects
  final pushManager = _getPushManager(registration);
  final options = _createSubscribeOptions(applicationServerKey);
  final subscriptionAny = await _subscribe(pushManager, options).toDart;

  if (subscriptionAny == null) {
    throw Exception('Failed to create push subscription');
  }

  return subscriptionAny as JSObject;
}

@JS()
external JSObject _getPushManager(JSObject registration);

@JS()
external JSObject _createSubscribeOptions(JSUint8Array applicationServerKey);

@JS()
external JSPromise _subscribe(JSObject pushManager, JSObject options);

@JS()
external String _subscriptionToJson(JSObject subscription);

// Helper script for push manager
void injectPushManagerHelper() {
  const script = '''
    if (typeof window._getPushManager === 'undefined') {
      window._getPushManager = function(registration) {
        return registration.pushManager;
      };

      window._createSubscribeOptions = function(applicationServerKey) {
        return {
          userVisibleOnly: true,
          applicationServerKey: applicationServerKey
        };
      };

      window._subscribe = function(pushManager, options) {
        return pushManager.subscribe(options);
      };

      window._subscriptionToJson = function(subscription) {
        return JSON.stringify(subscription);
      };
    }
  ''';

  try {
    _eval(script);
  } catch (e) {
  }
}

/// Setup listener for Service Worker messages (notification clicks)
void setupServiceWorkerMessageListener(void Function(String url, String? bookingId, String? screen) onNavigate) {
  if (!kIsWeb) return;

  const script = '''
    if (typeof window._swMessageListenerSetup === 'undefined') {
      window._swMessageListenerSetup = true;

      // Listen for messages from Service Worker
      navigator.serviceWorker.addEventListener('message', function(event) {
        console.log('[Flutter] Message from Service Worker:', event.data);

        if (event.data && event.data.type === 'NOTIFICATION_CLICK') {
          console.log('[Flutter] Notification clicked, navigating to:', event.data.url);

          // Call Flutter callback via window object
          if (window._onServiceWorkerNavigate) {
            window._onServiceWorkerNavigate(
              event.data.url || '/',
              event.data.bookingId || null,
              event.data.screen || null
            );
          }
        }
      });

      console.log('[Flutter] ✅ Service Worker message listener setup complete');
    }
  ''';

  try {
    _eval(script);

    // Register Flutter callback
    _registerNavigationCallback(onNavigate);

  } catch (e) {
  }
}

/// Register Flutter navigation callback
void _registerNavigationCallback(void Function(String url, String? bookingId, String? screen) onNavigate) {
  final callbackScript = '''
    window._onServiceWorkerNavigate = function(url, bookingId, screen) {
      console.log('[Flutter Callback] Navigating to:', url, 'bookingId:', bookingId, 'screen:', screen);

      // Notify Dart via a custom event
      const event = new CustomEvent('flutter_navigate', {
        detail: { url: url, bookingId: bookingId, screen: screen }
      });
      window.dispatchEvent(event);
    };
  ''';

  try {
    _eval(callbackScript);
  } catch (e) {
  }
}
