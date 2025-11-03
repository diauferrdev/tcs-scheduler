// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web-specific implementation
void signalAppReady() {
  try {
    // Dispatch custom event for web splash screen
    html.window.dispatchEvent(html.CustomEvent('app-ready'));
  } catch (e) {
  }
}
