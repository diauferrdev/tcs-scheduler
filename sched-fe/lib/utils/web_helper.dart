// ignore_for_file: avoid_web_libraries_in_flutter, undefined_hidden_name
import 'package:flutter/foundation.dart' show kIsWeb;

// Platform-specific implementations
import 'web_helper_stub.dart'
    if (dart.library.html) 'web_helper_web.dart' as platform;

/// Cross-platform helper for web-specific functionality
class WebHelper {
  /// Signal to web platform that the app is ready (removes splash screen)
  static void signalAppReady() {
    if (!kIsWeb) return;
    platform.signalAppReady();
  }

  /// Check if PWA install prompt is available
  static bool pwaCanInstall() {
    if (!kIsWeb) return false;
    return platform.pwaCanInstall();
  }

  /// Trigger PWA install prompt
  static Future<bool> pwaInstall() async {
    if (!kIsWeb) return false;
    return platform.pwaInstall();
  }
}
