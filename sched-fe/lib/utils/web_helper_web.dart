// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web-specific implementation
void signalAppReady() {
  try {
    // Dispatch custom event for web splash screen
    html.window.dispatchEvent(html.CustomEvent('app-ready'));
    print('[WebHelper] ✅ App ready signal sent to web');
  } catch (e) {
    print('[WebHelper] Error dispatching app-ready event: $e');
  }
}
