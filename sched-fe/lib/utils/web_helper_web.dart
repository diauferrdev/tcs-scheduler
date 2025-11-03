// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show debugPrint;

/// Web-specific implementation
void signalAppReady() {
  try {
    // Dispatch custom event for web splash screen
    html.window.dispatchEvent(html.CustomEvent('app-ready'));
    debugPrint('[WebHelper] ✅ App ready signal sent to web');
  } catch (e) {
    debugPrint('[WebHelper] Error dispatching app-ready event: $e');
  }
}
